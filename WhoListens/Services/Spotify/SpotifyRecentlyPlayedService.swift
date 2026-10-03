import Foundation

struct SpotifyRecentlyPlayedItem: Decodable, Identifiable {
    let track: SpotifySavedTrack
    let playedAt: Date

    enum CodingKeys: String, CodingKey {
        case track
        case playedAt = "played_at"
    }

    var id: String { "\(track.id)-\(playedAt.timeIntervalSince1970)" }
}

enum SpotifyRecentlyPlayedError: Error {
    case permissionRequired
    case unavailable(String)
}

enum SpotifyRecentlyPlayedService {
    static func recent(providerToken: String, limit: Int = 20) async throws -> [SpotifyRecentlyPlayedItem] {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/recently-played")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 50)))]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(providerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyPlaylistError.requestFailed
        }
        guard response.statusCode == 200 else {
            struct APIError: Decodable {
                struct Detail: Decodable { let message: String? }
                let error: Detail?
            }
            let detail = try? JSONDecoder().decode(APIError.self, from: data).error?.message
            let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
            if challenge.localizedCaseInsensitiveContains("insufficient_scope") ||
                (response.statusCode == 403 && detail?.localizedCaseInsensitiveContains("scope") == true) {
                throw SpotifyRecentlyPlayedError.permissionRequired
            }
            throw SpotifyRecentlyPlayedError.unavailable(
                "Spotify couldn't load listening history (\(response.statusCode))."
            )
        }

        // A removed or unavailable track can be missing fields. Keep the rest of
        // the listening history instead of failing the entire refresh.
        struct Play: Decodable {
            let item: SpotifyRecentlyPlayedItem?

            init(from decoder: Decoder) throws {
                item = try? SpotifyRecentlyPlayedItem(from: decoder)
            }
        }
        struct Page: Decodable { let items: [Play] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid Spotify play time"
            )
        }
        let page = try decoder.decode(Page.self, from: data)
        let items = page.items.compactMap(\.item)
        if !page.items.isEmpty && items.isEmpty {
            throw SpotifyRecentlyPlayedError.unavailable("Spotify returned listening history we couldn't read.")
        }
        return items
    }
}
