import Foundation

/// Loads public album thumbnails from Spotify without a user session or client secret.
struct SpotifyPublicArtworkService: Sendable {
    static let albumIDs = [
        "4yP0hdKOZPNshxUOjY0cZj", // After Hours
        "0hvT3yIEysuuvkK73vgdcW", // GNX
        "7aJuG4TFXa2hmE4z1yxc3n", // HIT ME HARD AND SOFT
        "4AdZV63ycxFLF6Hcol0QnB", // Starboy
        "4aawyAB9vmqN3uQ7FjRGTy"  // Global Warming
    ]

    func albumArtworkData() async -> [Data?] {
        var artwork = Array<Data?>(repeating: nil, count: Self.albumIDs.count)
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, albumID) in Self.albumIDs.enumerated() {
                group.addTask {
                    (index, await artworkData(for: albumID))
                }
            }
            for await (index, data) in group {
                artwork[index] = data
            }
        }
        return artwork
    }

    private func artworkData(for albumID: String) async -> Data? {
        guard var components = URLComponents(string: "https://open.spotify.com/oembed") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://open.spotify.com/album/\(albumID)")
        ]
        guard let endpoint = components.url else { return nil }

        do {
            var metadataRequest = URLRequest(url: endpoint)
            metadataRequest.timeoutInterval = 4
            let (metadata, metadataResponse) = try await URLSession.shared.data(for: metadataRequest)
            guard let metadataResponse = metadataResponse as? HTTPURLResponse,
                  metadataResponse.statusCode == 200 else { return nil }

            let result = try JSONDecoder().decode(SpotifyOEmbedAlbum.self, from: metadata)
            guard let imageURL = result.thumbnailURL, imageURL.scheme == "https" else { return nil }

            var imageRequest = URLRequest(url: imageURL)
            imageRequest.timeoutInterval = 4
            let (imageData, imageResponse) = try await URLSession.shared.data(for: imageRequest)
            guard let imageResponse = imageResponse as? HTTPURLResponse,
                  imageResponse.statusCode == 200 else { return nil }
            return imageData
        } catch {
            return nil
        }
    }
}

private struct SpotifyOEmbedAlbum: Decodable {
    let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case thumbnailURL = "thumbnail_url"
    }
}
