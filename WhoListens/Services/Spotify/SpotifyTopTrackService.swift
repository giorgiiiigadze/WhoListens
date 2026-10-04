import Foundation

enum SpotifyTopTrackError: Error {
    case permissionRequired
    case unavailable
}

enum SpotifyTopTrackService {
    static func topTracks(providerToken: String) async throws -> [SpotifySavedTrack] {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/tracks")!
        components.queryItems = [
            URLQueryItem(name: "time_range", value: "medium_term"),
            URLQueryItem(name: "limit", value: "8"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(providerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyTopTrackError.unavailable
        }
        if response.statusCode == 403 {
            let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
            let message = String(data: data, encoding: .utf8) ?? ""
            if challenge.localizedCaseInsensitiveContains("insufficient_scope") ||
                message.localizedCaseInsensitiveContains("scope") {
                throw SpotifyTopTrackError.permissionRequired
            }
        }
        guard response.statusCode == 200 else {
            throw SpotifyTopTrackError.unavailable
        }

        struct Page: Decodable { let items: [SpotifySavedTrack] }
        return try JSONDecoder().decode(Page.self, from: data).items
    }
}
