import Foundation

struct SpotifyTopArtist: Decodable, Identifiable {
    let id: String
    let name: String
    let images: [ArtworkImage]

    struct ArtworkImage: Decodable {
        let url: URL
    }

    var artworkURL: URL? { images.first?.url }
}

enum SpotifyTopArtistError: Error {
    case permissionRequired
    case unavailable
}

enum SpotifyTopArtistService {
    static func topArtists(providerToken: String) async throws -> [SpotifyTopArtist] {
        var components = URLComponents(string: "https://api.spotify.com/v1/me/top/artists")!
        components.queryItems = [
            URLQueryItem(name: "time_range", value: "medium_term"),
            URLQueryItem(name: "limit", value: "10"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(providerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyTopArtistError.unavailable
        }
        if response.statusCode == 403 {
            let challenge = response.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
            let message = String(data: data, encoding: .utf8) ?? ""
            if challenge.localizedCaseInsensitiveContains("insufficient_scope") ||
                message.localizedCaseInsensitiveContains("scope") {
                throw SpotifyTopArtistError.permissionRequired
            }
        }
        guard response.statusCode == 200 else {
            throw SpotifyTopArtistError.unavailable
        }

        struct Page: Decodable { let items: [SpotifyTopArtist] }
        return try JSONDecoder().decode(Page.self, from: data).items
    }
}
