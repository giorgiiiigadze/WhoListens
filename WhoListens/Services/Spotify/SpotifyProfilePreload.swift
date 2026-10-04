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
    private(set) var topArtists: [SpotifyTopArtist]?
    private(set) var topTracks: [SpotifySavedTrack]?
    private var loadedAt: Date?
    private var artwork: [URL: UIImage] = [:]

    private init() {}

    func preload(for userID: UUID) async {
        if self.userID != userID {
            clear()
            self.userID = userID
        }
        if let loadedAt, Date().timeIntervalSince(loadedAt) < 180 { return }
        do {
            let token = try await SpotifyAccessService.shared.accessToken()
            guard let token else { return }

            async let recentResult = try? await SpotifyRecentlyPlayedService.recent(providerToken: token)
            async let artistResult = try? await SpotifyTopArtistService.topArtists(providerToken: token)
            async let trackResult = try? await SpotifyTopTrackService.topTracks(providerToken: token)
            async let savedResult = try? await SpotifySavedTrackService.recent(providerToken: token)
            async let playlistResult = try? await SpotifyPlaylistService.playlists(providerToken: token)

            let (recent, artists, tracks, saved, lists) = await (
                recentResult, artistResult, trackResult, savedResult, playlistResult
            )
            guard self.userID == userID else { return }
            recentlyPlayed = recent ?? recentlyPlayed
            topArtists = artists ?? topArtists
            topTracks = tracks ?? topTracks
            savedTracks = saved ?? savedTracks
            playlists = lists ?? playlists
            loadedAt = Date()
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

    func topArtists(for userID: UUID) -> [SpotifyTopArtist]? {
        self.userID == userID ? topArtists : nil
    }

    func topTracks(for userID: UUID) -> [SpotifySavedTrack]? {
        self.userID == userID ? topTracks : nil
    }

    func storeTopArtists(_ artists: [SpotifyTopArtist], for userID: UUID) {
        guard self.userID == userID else { return }
        topArtists = artists
    }

    func storeTopTracks(_ tracks: [SpotifySavedTrack], for userID: UUID) {
        guard self.userID == userID else { return }
        topTracks = tracks
    }

    func storeRecentlyPlayed(_ items: [SpotifyRecentlyPlayedItem], for userID: UUID) {
        guard self.userID == userID else { return }
        recentlyPlayed = items
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
            + (topTracks?.prefix(3).compactMap(\.artworkURL) ?? [])
            + (topArtists?.prefix(3).compactMap(\.artworkURL) ?? [])
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
        topArtists = nil
        topTracks = nil
        loadedAt = nil
        artwork = [:]
    }
}
