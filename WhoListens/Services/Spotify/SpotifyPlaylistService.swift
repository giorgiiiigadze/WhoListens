import Foundation
import Supabase

struct SpotifyPlaylist: Decodable, Identifiable {
    let id: String
    let name: String
    let images: [Artwork]
    let externalURLs: ExternalURLs
    let items: ItemCount?
    let tracks: ItemCount?

    struct Artwork: Decodable {
        let url: URL
    }

    struct ExternalURLs: Decodable {
        let spotify: URL?
    }

    struct ItemCount: Decodable {
        let total: Int
    }

    enum CodingKeys: String, CodingKey {
        case id, name, images, items, tracks
        case externalURLs = "external_urls"
    }

    var artworkURL: URL? { images.first?.url }
    var spotifyURL: URL? { externalURLs.spotify }
    var songCount: Int? { items?.total ?? tracks?.total }
}

enum SpotifyPlaylistError: Error {
    case authorizationRequired
    case requestFailed
}

enum SpotifyPlaylistService {
    static let scopes = "user-read-email playlist-read-private playlist-read-collaborative user-library-read user-read-recently-played user-top-read"

    static func connect() async throws -> Session {
        try await supabase.auth.signInWithOAuth(
            provider: .spotify,
            redirectTo: URL(string: "com.giorgigiorgadze.wholistens://auth-callback"),
            scopes: scopes
        )
    }

    static func playlists(providerToken: String) async throws -> [SpotifyPlaylist] {
        struct Page: Decodable {
            let items: [SpotifyPlaylist]
            let next: URL?
        }

        var playlists: [SpotifyPlaylist] = []
        var offset = 0

        while true {
            var components = URLComponents(string: "https://api.spotify.com/v1/me/playlists")!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "50"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            var request = URLRequest(url: components.url!)
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

            let page = try JSONDecoder().decode(Page.self, from: data)
            playlists.append(contentsOf: page.items)
            guard page.next != nil, !page.items.isEmpty else { return playlists }
            offset += page.items.count
        }
    }
}
