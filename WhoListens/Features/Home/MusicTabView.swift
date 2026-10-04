import AuthenticationServices
import SwiftUI

struct MusicTabView: View {
    @Environment(\.openURL) private var openURL
    @State private var playlists: [SpotifyPlaylist] = []
    @State private var savedTracks: [SpotifySavedTrack] = []
    @State private var isLoading = true
    @State private var isConnecting = false
    @State private var needsConnection = false
    @State private var savedTracksNeedPermission = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your music")
                        .font(AppTypography.display)
                    Text("Everything you love, all in one place.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.63))
                }

                if isLoading {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 14) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white.opacity(0.11))
                                    .frame(width: 150, height: 150)
                            }
                        }
                        VStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { _ in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.white.opacity(0.11))
                                        .frame(width: 52, height: 52)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Capsule().fill(.white.opacity(0.12)).frame(width: 135, height: 13)
                                        Capsule().fill(.white.opacity(0.08)).frame(width: 180, height: 10)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .accessibilityHidden(true)
                } else if needsConnection {
                    connectionCard
                } else {
                    if let errorMessage {
                        HStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Button("Retry") { Task { await loadMusic() } }
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(18)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                    }

                    playlistsSection
                    savedSongsSection
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await loadMusic(forceRefresh: true) }
        .task { await loadMusic() }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Playlists", subtitle: "The collections that sound like you")

            if playlists.isEmpty {
                emptyState("No playlists yet", symbol: "square.stack")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(playlists) { playlist in
                            Button {
                                if let url = playlist.spotifyURL { openURL(url) }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    artwork(playlist.artworkURL, size: 150)
                                    Text(playlist.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .lineLimit(1)
                                    Text(playlist.songCount.map { "\($0) songs" } ?? "Open in Spotify")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                .frame(width: 150, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .disabled(playlist.spotifyURL == nil)
                        }
                    }
                }
                .contentMargins(.trailing, 22)
            }
        }
    }

    private var savedSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Saved songs", subtitle: "Your latest favorites")

            if savedTracksNeedPermission {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Allow access to your saved songs to see them here.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                    Button("Allow saved songs") { Task { await connectSpotify() } }
                        .font(.system(size: 15, weight: .semibold))
                        .disabled(isConnecting)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            } else if savedTracks.isEmpty {
                emptyState("No saved songs yet", symbol: "heart")
            } else {
                VStack(spacing: 0) {
                    ForEach(savedTracks) { track in
                        Button {
                            if let url = track.spotifyURL { openURL(url) }
                        } label: {
                            HStack(spacing: 13) {
                                artwork(track.artworkURL, size: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .lineLimit(1)
                                    Text(track.artistNames)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.56))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .disabled(track.spotifyURL == nil)
                        if track.id != savedTracks.last?.id {
                            Divider().overlay(.white.opacity(0.1))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.25, green: 0.84, blue: 0.53))
            Text("Bring your music in.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Text("Connect Spotify to see your playlists and saved songs.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
            }
            Button { Task { await connectSpotify() } } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView().tint(.black)
                    } else {
                        Image("SpotifyMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .colorMultiply(Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255))
                    }
                    Text(isConnecting ? "Connecting…" : "Connect Spotify")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 27))
    }

    private func artwork(_ url: URL?, size: CGFloat) -> some View {
        SpotifyCachedArtwork(url: url, size: size, cornerRadius: size * 0.14)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 23, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55))
        }
    }

    private func emptyState(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.45))
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
    }

    @MainActor
    private func loadMusic(forceRefresh: Bool = false) async {
        isLoading = playlists.isEmpty && savedTracks.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let userID = try await supabase.auth.session.user.id
            if !forceRefresh,
               let cachedPlaylists = SpotifyProfilePreload.shared.playlists(for: userID),
               let cachedTracks = SpotifyProfilePreload.shared.savedTracks(for: userID) {
                playlists = cachedPlaylists
                savedTracks = cachedTracks
                needsConnection = false
                savedTracksNeedPermission = false
                return
            }
            let token = try await SpotifyAccessService.shared.accessToken()
            guard let token else {
                needsConnection = true
                return
            }
            await fetchMusic(token: token)
        } catch {
            errorMessage = "Could not load your music right now."
        }
    }

    @MainActor
    private func fetchMusic(token: String) async {
        do {
            playlists = try await SpotifyPlaylistService.playlists(providerToken: token)
            needsConnection = false
            do {
                savedTracks = try await SpotifySavedTrackService.recent(providerToken: token)
                savedTracksNeedPermission = false
            } catch SpotifyPlaylistError.authorizationRequired {
                savedTracks = []
                savedTracksNeedPermission = true
            } catch {
                savedTracks = []
                errorMessage = "Saved songs could not be loaded right now."
            }
        } catch SpotifyPlaylistError.authorizationRequired {
            needsConnection = true
        } catch {
            errorMessage = "Could not load your playlists right now."
        }
    }

    @MainActor
    private func connectSpotify() async {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            let token = try await SpotifyAccessService.shared.connect()
            await fetchMusic(token: token)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                errorMessage = "Could not connect to Spotify. Please try again."
            }
        }
    }
}
