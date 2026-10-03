import Foundation

struct SpotifySavedTrack: Decodable, Identifiable {
    let id: String
    let name: String
    let artists: [Artist]
    let album: Album
    let externalURLs: ExternalURLs

    struct Artist: Decodable { let name: String }
    struct Album: Decodable { let images: [Image] }
    struct Image: Decodable { let url: URL }
    struct ExternalURLs: Decodable { let spotify: URL? }

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
        case externalURLs = "external_urls"
    }

    var artworkURL: URL? { album.images.first?.url }
    var spotifyURL: URL? { externalURLs.spotify }
    var artistNames: String { artists.map(\.name).joined(separator: ", ") }
}

enum SpotifySavedTrackService {
    static func recent(providerToken: String) async throws -> [SpotifySavedTrack] {
        let url = URL(string: "https://api.spotify.com/v1/me/tracks?limit=10")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(providerToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyPlaylistError.requestFailed
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw SpotifyPlaylistError.authorizationRequired
        }
        guard response.statusCode == 200 else {
            throw SpotifyPlaylistError.requestFailed
        }

        struct SavedItem: Decodable { let track: SpotifySavedTrack? }
        struct Page: Decodable { let items: [SavedItem] }
        return try JSONDecoder().decode(Page.self, from: data).items.compactMap(\.track)
    }
}
