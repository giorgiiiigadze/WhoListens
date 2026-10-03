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
                    ProgressView("Loading your music…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 260)
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
        .background(Color(red: 18 / 255, green: 18 / 255, blue: 23 / 255).ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await loadMusic() }
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
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.28))
                .foregroundStyle(.white.opacity(0.48))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.electricPurple.opacity(0.45))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14))
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
    private func loadMusic() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token: String?
            if let nativeToken = try await SpotifyAppAuthenticator.shared.accessToken() {
                token = nativeToken
            } else {
                token = try await supabase.auth.session.providerToken
            }
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
            let token = try await SpotifyAppAuthenticator.shared.connect()
            await fetchMusic(token: token)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                errorMessage = "Could not connect to Spotify. Please try again."
            }
        }
    }
}
