import Foundation
import UIKit

/// Keeps the first profile render ready while the signed-in splash is visible.
@MainActor
final class SpotifyProfilePreload {
    static let shared = SpotifyProfilePreload()

    private var userID: UUID?
    private(set) var playlists: [SpotifyPlaylist]?
    private(set) var savedTracks: [SpotifySavedTrack]?
    private(set) var recentlyPlayed: [SpotifyRecentlyPlayedItem]?
    private var artwork: [URL: UIImage] = [:]

    private init() {}

    func preload(for userID: UUID) async {
        if self.userID != userID {
            clear()
            self.userID = userID
        }
        do {
            let token: String?
            if let nativeToken = try await SpotifyAppAuthenticator.shared.accessToken() {
                token = nativeToken
            } else {
                token = try await supabase.auth.session.providerToken
            }
            guard let token else { return }

            if recentlyPlayed == nil {
                recentlyPlayed = try? await SpotifyRecentlyPlayedService.recent(providerToken: token)
            }
            if savedTracks == nil {
                savedTracks = try? await SpotifySavedTrackService.recent(providerToken: token)
            }
            if playlists == nil {
                playlists = try? await SpotifyPlaylistService.playlists(providerToken: token)
            }
            await warmArtwork(for: userID)
        } catch {
            // ProfileView retains its own retry and permission handling.
        }
    }

    func playlists(for userID: UUID) -> [SpotifyPlaylist]? {
        self.userID == userID ? playlists : nil
    }

    func savedTracks(for userID: UUID) -> [SpotifySavedTrack]? {
        self.userID == userID ? savedTracks : nil
    }

    func recentlyPlayed(for userID: UUID) -> [SpotifyRecentlyPlayedItem]? {
        self.userID == userID ? recentlyPlayed : nil
    }

    func image(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return artwork[url]
    }

    func loadArtwork(at url: URL) async -> UIImage? {
        if let cached = artwork[url] { return cached }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        artwork[url] = image
        return image
    }

    private func warmArtwork(for userID: UUID) async {
        let candidates = (recentlyPlayed?.prefix(3).compactMap(\.track.artworkURL) ?? [])
            + (savedTracks?.prefix(6).compactMap(\.artworkURL) ?? [])
            + (playlists?.prefix(8).compactMap(\.artworkURL) ?? [])
        var seen = Set<URL>()
        let urls = candidates.filter { seen.insert($0).inserted && artwork[$0] == nil }

        await withTaskGroup(of: (URL, Data?).self) { group in
            for url in urls {
                group.addTask {
                    guard let (data, response) = try? await URLSession.shared.data(from: url),
                          (response as? HTTPURLResponse)?.statusCode == 200 else {
                        return (url, nil)
                    }
                    return (url, data)
                }
            }
            for await (url, data) in group {
                guard self.userID == userID, let data, let image = UIImage(data: data) else { continue }
                artwork[url] = image
            }
        }
    }

    func clear() {
        userID = nil
        playlists = nil
        savedTracks = nil
        recentlyPlayed = nil
        artwork = [:]
    }
}
