import Foundation
@preconcurrency import SpotifyiOS
import Security
import UIKit

/// Connects an existing WhoListens account to the installed Spotify app.
/// Supabase remains responsible for WhoListens account sign-in.
@MainActor
final class SpotifyAppAuthenticator {
    static let shared = SpotifyAppAuthenticator()

    private let callbackURL = URL(string: "wholistens-spotify://callback")!
    private let keychainAccount = "spotify-native-session"
    private let pendingSignInKey = "spotifyNativeSignInPending"
    private lazy var sessionDelegate = SpotifySessionDelegate(owner: self)
    private var sessionManager: SPTSessionManager?
    private var continuation: CheckedContinuation<String, Error>?

    private init() {}

    private var manager: SPTSessionManager {
        if let sessionManager { return sessionManager }
        let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: callbackURL)
        configuration.tokenSwapURL = supabaseURL.appendingPathComponent("functions/v1/spotify-auth/swap")
        configuration.tokenRefreshURL = supabaseURL.appendingPathComponent("functions/v1/spotify-auth/refresh")
        let manager = SPTSessionManager(configuration: configuration, delegate: sessionDelegate)
        if let storedSession = loadSession() { manager.session = storedSession }
        sessionManager = manager
        return manager
    }

    func connect() async throws -> String {
        guard continuation == nil else { throw SpotifyAppAuthenticatorError.connectionInProgress }
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
              !clientID.isEmpty,
              !clientID.hasPrefix("$(") else {
            throw SpotifyAppAuthenticatorError.missingClientID
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let scopes: SPTScope = [.playlistReadPrivate, .playlistReadCollaborative, .userReadEmail, .userLibraryRead]
            manager.initiateSession(with: scopes, options: .clientOnly, campaign: "wholistens-sign-in")
        }
    }

    func accessToken() async throws -> String? {
        guard let session = manager.session else { return nil }
        if !session.isExpired { return session.accessToken }
        guard continuation == nil else { throw SpotifyAppAuthenticatorError.connectionInProgress }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.renewSession()
        }
    }

    func signIn() async throws {
        UserDefaults.standard.set(true, forKey: pendingSignInKey)
        do {
            let token = try await connect()
            try await completeSignIn(accessToken: token)
            UserDefaults.standard.removeObject(forKey: pendingSignInKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: pendingSignInKey)
            throw error
        }
    }

    private func completeSignIn(accessToken: String) async throws {
        guard let refreshHandle = manager.session?.refreshToken, !refreshHandle.isEmpty else {
            throw SpotifyAppAuthenticatorError.accountExchangeFailed
        }
        var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/spotify-auth/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["access_token": accessToken, "refresh_handle": refreshHandle])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw SpotifyAppAuthenticatorError.accountExchangeFailed
        }
        let exchange = try JSONDecoder().decode(AccountExchange.self, from: data)
        _ = try await supabase.auth.verifyOTP(tokenHash: exchange.tokenHash, type: .magiclink)
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: pendingSignInKey)
        sessionManager?.session = nil
        removeStoredSession()
    }

    private func removeStoredSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "WhoListens",
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func handleCallback(_ url: URL) {
        guard url.scheme == callbackURL.scheme else { return }
        manager.application(UIApplication.shared, open: url, options: [:])
    }

    fileprivate func didInitiate(_ session: SPTSession) {
        saveSession(session)
        if continuation == nil && UserDefaults.standard.bool(forKey: pendingSignInKey) {
            Task {
                try? await completeSignIn(accessToken: session.accessToken)
                UserDefaults.standard.removeObject(forKey: pendingSignInKey)
            }
        }
        finish(with: .success(session.accessToken))
    }

    fileprivate func didFail(_ error: Error) {
        if continuation == nil {
            UserDefaults.standard.removeObject(forKey: pendingSignInKey)
        }
        finish(with: .failure(error))
    }

    fileprivate func didRenew(_ session: SPTSession) {
        saveSession(session)
        finish(with: .success(session.accessToken))
    }

    private func finish(with result: Result<String, Error>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }

    private func saveSession(_ session: SPTSession) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: session, requiringSecureCoding: true) else { return }
        removeStoredSession()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "WhoListens",
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
        sessionManager?.session = session
    }

    private func loadSession() -> SPTSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "WhoListens",
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: SPTSession.self, from: data)
    }
}

/// Spotify's Objective-C callbacks are not actor-isolated. This adapter keeps
/// protocol conformance separate from the main-actor-owned authentication state.
private final class SpotifySessionDelegate: NSObject, SPTSessionManagerDelegate {
    weak var owner: SpotifyAppAuthenticator?

    init(owner: SpotifyAppAuthenticator) {
        self.owner = owner
    }

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        let owner = owner
        let session = DelegateValue(session)
        Task { @MainActor in owner?.didInitiate(session.value) }
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        let owner = owner
        let error = DelegateValue(error)
        Task { @MainActor in owner?.didFail(error.value) }
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        let owner = owner
        let session = DelegateValue(session)
        Task { @MainActor in owner?.didRenew(session.value) }
    }
}

/// SPTSession has no Sendable annotation in the Spotify SDK. The adapter only
/// transfers SDK callback values to the main actor; they are not used elsewhere.
private struct DelegateValue<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

private struct AccountExchange: Decodable {
    let tokenHash: String

    enum CodingKeys: String, CodingKey { case tokenHash = "token_hash" }
}

enum SpotifyAppAuthenticatorError: LocalizedError {
    case missingClientID
    case connectionInProgress
    case accountExchangeFailed

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Spotify connection has not been configured yet."
        case .connectionInProgress:
            return "A Spotify connection is already in progress."
        case .accountExchangeFailed:
            return "Could not sign in to WhoListens with this Spotify account."
        }
    }
}
