import Foundation

/// Resolves the Spotify connection owned by the current WhoListens user.
/// A short cache avoids refreshing the same Spotify token for every section.
@MainActor
final class SpotifyAccessService {
    static let shared = SpotifyAccessService()

    private struct Credential {
        let userID: UUID
        let token: String
        let expiresAt: Date
        let spotifyID: String?
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: TimeInterval
        let spotifyID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case spotifyID = "spotify_id"
        }
    }

    private var cached: Credential?
    private var pending: (userID: UUID, task: Task<Credential?, Error>)?

    private init() {}

    func accessToken() async throws -> String? {
        let session = try await supabase.auth.session
        let userID = session.user.id
        if let cached, cached.userID == userID, cached.expiresAt > Date() {
            return cached.token
        }
        if let pending, pending.userID == userID {
            return try await pending.task.value?.token
        }

        let task = Task {
            try await fetchCredential(for: userID, sessionToken: session.accessToken)
        }
        pending = (userID, task)
        defer { pending = nil }
        let credential = try await task.value
        cached = credential
        return credential?.token
    }

    func clear() {
        pending?.task.cancel()
        pending = nil
        cached = nil
    }

    func connect() async throws -> String {
        let nativeToken = try await SpotifyAppAuthenticator.shared.connect()
        clear()
        guard let token = try await accessToken() else {
            throw SpotifyAccessError.connectionUnavailable
        }
        if let linkedID = cached?.spotifyID {
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
            request.setValue("Bearer \(nativeToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let identity = try? JSONDecoder().decode(SpotifyIdentity.self, from: data),
                  identity.id == linkedID else {
                clear()
                throw SpotifyAccessError.accountMismatch
            }
        }
        return token
    }

    private struct SpotifyIdentity: Decodable { let id: String }

    private func fetchCredential(for userID: UUID, sessionToken: String) async throws -> Credential? {
        var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/spotify-auth/access"))
        request.httpMethod = "POST"
        request.setValue(supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyAccessError.unavailable
        }
        if response.statusCode == 404 {
            // Keep existing installations working until the updated function is
            // deployed. Once available, the server-owned connection is used.
            let fallback: String?
            if let native = try await SpotifyAppAuthenticator.shared.accessToken() {
                fallback = native
            } else {
                fallback = try await supabase.auth.session.providerToken
            }
            guard let fallback else { return nil }
            return Credential(userID: userID, token: fallback, expiresAt: Date().addingTimeInterval(60), spotifyID: nil)
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw SpotifyAccessError.connectionUnavailable
        }
        guard response.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data),
              !token.accessToken.isEmpty, token.expiresIn > 0 else {
            throw SpotifyAccessError.unavailable
        }
        return Credential(
            userID: userID,
            token: token.accessToken,
            expiresAt: Date().addingTimeInterval(max(1, token.expiresIn - 60)),
            spotifyID: token.spotifyID
        )
    }
}

enum SpotifyAccessError: LocalizedError {
    case connectionUnavailable
    case unavailable
    case accountMismatch

    var errorDescription: String? {
        switch self {
        case .connectionUnavailable:
            return "Your Spotify connection needs attention."
        case .unavailable:
            return "Spotify music could not be loaded right now."
        case .accountMismatch:
            return "This is a different Spotify account. Please use the account linked at sign-in."
        }
    }
}
