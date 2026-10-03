import AuthenticationServices
import PhotosUI
import SwiftUI

struct ProfileView: View {
    let profile: Profile
    let email: String?
    let joinedAt: Date?
    let age: Int?
    let showsCloseButton: Bool
    let onLogOut: (() -> Void)?
    let onPhotoChanged: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var displayedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var photoError: String?
    @State private var playlists: [SpotifyPlaylist] = []
    @State private var savedTracks: [SpotifySavedTrack] = []
    @State private var savedTracksError: String?
    @State private var savedTracksNeedsConnection = false
    @State private var isLoadingPlaylists = true
    @State private var isConnectingSpotify = false
    @State private var playlistNeedsConnection = false
    @State private var playlistError: String?

    init(
        profile: Profile,
        avatarImage: UIImage?,
        email: String?,
        joinedAt: Date?,
        age: Int?,
        showsCloseButton: Bool = true,
        onLogOut: (() -> Void)? = nil,
        onPhotoChanged: @escaping () async throws -> Void
    ) {
        self.profile = profile
        self.email = email
        self.joinedAt = joinedAt
        self.age = age
        self.showsCloseButton = showsCloseButton
        self.onLogOut = onLogOut
        self.onPhotoChanged = onPhotoChanged
        _displayedImage = State(initialValue: avatarImage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                VStack(spacing: 16) {
                    identityCard
                    factsCard
                    emptyCard(
                        title: "YOUR GUESSERS",
                        subtitle: "The ones who always get you right",
                        symbol: "person.2.wave.2.fill",
                        message: "Play with friends to see who knows your music best."
                    )
                    emptyCard(
                        title: "YOUR HITS",
                        subtitle: "The songs everyone guesses right",
                        symbol: "music.note.list",
                        message: "Your most recognized songs will appear here after you play."
                    )
                    musicCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .coordinateSpace(name: "profileScroll")
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showsCloseButton {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Close profile")
                } else if let onLogOut {
                    Menu {
                        Button("Log out", action: onLogOut)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Profile settings")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if isUpdatingPhoto {
                        ProgressView()
                    } else {
                        Image(systemName: "pencil")
                    }
                }
                .disabled(isUpdatingPhoto)
                .accessibilityLabel("Change profile photo")
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await updatePhoto(from: item) }
        }
        .task { await loadPlaylists() }
        .alert("Photo couldn't be updated", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "Please try again.")
        }
    }

    private var hero: some View {
        GeometryReader { geometry in
            let pullDistance = max(0, geometry.frame(in: .named("profileScroll")).minY)
            ZStack(alignment: .bottomLeading) {
                if let displayedImage {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height + pullDistance)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [AppColors.electricPurple, Color(red: 0.09, green: 0.08, blue: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 180, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.38), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.3), location: 0.62),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(profile.displayName.uppercased())
                        .font(AppTypography.display)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 8)
                    HStack(spacing: 8) {
                        Image("SpotifyMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Connected with Spotify")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height + pullDistance)
            .offset(y: -pullDistance)
        }
        .frame(height: 460)
    }

    private var identityCard: some View {
        friendsContent.profileGlassCard()
    }

    private var friendsContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
            Text("0 friends")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }

    private var factsCard: some View {
        HStack(alignment: .top, spacing: 8) {
            fact(symbol: "calendar", title: "JOINED", value: joinedAt?.formatted(.dateTime.month(.abbreviated).year()) ?? "—")
            fact(symbol: "person.fill", title: "AGE", value: age.map(String.init) ?? "—")
            fact(symbol: "gamecontroller.fill", title: "GAMES", value: "Play one")
        }
        .padding(.vertical, 25)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .profileGlassCard()
    }

    private func fact(symbol: String, title: String, value: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 25))
                .frame(height: 32)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyCard(title: String, subtitle: String, symbol: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(AppTypography.title)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 22)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .profileGlassCard()
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR MUSIC")
                .font(AppTypography.title)
            if isLoadingPlaylists {
                ProgressView("Loading playlists…")
                    .tint(.white)
            } else if playlistNeedsConnection {
                Text("Connect Spotify to see your playlists and saved songs.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                if let playlistError {
                    Text(playlistError)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Button {
                    Task { await connectSpotify() }
                } label: {
                    HStack(spacing: 10) {
                        if isConnectingSpotify {
                            ProgressView().tint(.black)
                        } else {
                            Image("SpotifyMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(4)
                                .background(.black, in: Circle())
                        }
                        Text(isConnectingSpotify ? "Connecting…" : "Connect Spotify")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.black)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isConnectingSpotify)
            } else if let playlistError {
                Text(playlistError)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                Button("Retry") { Task { await loadPlaylists() } }
                    .font(.system(size: 15, weight: .semibold))
            } else {
                Text("PLAYLISTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                if playlists.isEmpty {
                    Text("No playlists yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                ForEach(playlists) { playlist in
                    Button {
                        if let url = playlist.spotifyURL { openURL(url) }
                    } label: {
                        playlistRow(playlist)
                    }
                    .buttonStyle(.plain)
                    .disabled(playlist.spotifyURL == nil)
                    if playlist.id != playlists.last?.id {
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
                Divider().overlay(.white.opacity(0.2))
                Text("SAVED SONGS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                if let savedTracksError {
                    Text(savedTracksError)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                    if savedTracksNeedsConnection {
                        Button("Allow saved songs") { Task { await connectSpotify() } }
                            .font(.system(size: 15, weight: .semibold))
                            .disabled(isConnectingSpotify)
                    }
                } else if savedTracks.isEmpty {
                    Text("No saved songs yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                ForEach(savedTracks) { track in
                    Button {
                        if let url = track.spotifyURL { openURL(url) }
                    } label: {
                        savedTrackRow(track)
                    }
                    .buttonStyle(.plain)
                    .disabled(track.spotifyURL == nil)
                }
            }
            if let email {
                Divider().overlay(.white.opacity(0.2))
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .profileGlassCard()
    }

    private func playlistRow(_ playlist: SpotifyPlaylist) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: playlist.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.1))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                if let count = playlist.songCount {
                    Text("\(count) songs")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
            if playlist.spotifyURL != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func savedTrackRow(_ track: SpotifySavedTrack) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.1))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(track.artistNames)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if track.spotifyURL != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @MainActor
    private func loadPlaylists() async {
        isLoadingPlaylists = true
        playlistError = nil
        defer { isLoadingPlaylists = false }
        do {
            let nativeToken = try await SpotifyAppAuthenticator.shared.accessToken()
            let token: String?
            if let nativeToken {
                token = nativeToken
            } else {
                token = try await supabase.auth.session.providerToken
            }
            guard let token else {
                playlistNeedsConnection = true
                return
            }
            try await fetchPlaylists(token: token)
        } catch {
            playlistError = "Could not load playlists. Please try again."
        }
    }

    @MainActor
    private func fetchPlaylists(token: String) async throws {
        do {
            playlists = try await SpotifyPlaylistService.playlists(providerToken: token)
            do {
                savedTracks = try await SpotifySavedTrackService.recent(providerToken: token)
                savedTracksError = nil
                savedTracksNeedsConnection = false
            } catch SpotifyPlaylistError.authorizationRequired {
                savedTracks = []
                savedTracksError = "Spotify needs permission to show saved songs."
                savedTracksNeedsConnection = true
            } catch {
                savedTracks = []
                savedTracksError = "Could not load saved songs right now."
                savedTracksNeedsConnection = false
            }
            playlistNeedsConnection = false
            playlistError = nil
        } catch SpotifyPlaylistError.authorizationRequired {
            playlistNeedsConnection = true
        }
    }

    @MainActor
    private func connectSpotify() async {
        guard !isConnectingSpotify else { return }
        isConnectingSpotify = true
        defer { isConnectingSpotify = false }
        do {
            let token = try await SpotifyAppAuthenticator.shared.connect()
            try await fetchPlaylists(token: token)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                playlistError = "Could not connect to Spotify. Please try again."
            }
        }
    }

    @MainActor
    private func updatePhoto(from item: PhotosPickerItem) async {
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let jpeg = PendingProfilePhoto.preparedJPEG(from: data),
                  let image = UIImage(data: jpeg) else {
                photoError = "Choose a valid image and try again."
                return
            }
            try PendingProfilePhoto.save(jpeg)
            try await onPhotoChanged()
            displayedImage = image
            photoError = nil
        } catch {
            photoError = error.localizedDescription
        }
    }
}

private extension View {
    @ViewBuilder
    func profileGlassCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.clear, in: shape)
                .background(Color(white: 0.08).opacity(0.9), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
        } else {
            self
                .background(Color(white: 0.08).opacity(0.9), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
        }
    }
}
