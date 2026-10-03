import AuthenticationServices
import PhotosUI
import SwiftUI

struct ProfileView: View {
    let profile: Profile
    let email: String?
    let joinedAt: Date?
    let age: Int?
    let onLogOut: (() -> Void)?
    let onPhotoChanged: () async throws -> Void

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
    @State private var recentlyPlayed: [SpotifyRecentlyPlayedItem] = []
    @State private var isLoadingRecentlyPlayed = true
    @State private var recentNeedsPermission = false
    @State private var recentError: String?
    @State private var showsAllRecent = false
    @AppStorage("recentHistoryUpgradeAttemptedForUserID") private var recentUpgradeAttemptedForUserID = ""

    init(
        profile: Profile,
        avatarImage: UIImage?,
        email: String?,
        joinedAt: Date?,
        age: Int?,
        onLogOut: (() -> Void)? = nil,
        onPhotoChanged: @escaping () async throws -> Void
    ) {
        self.profile = profile
        self.email = email
        self.joinedAt = joinedAt
        self.age = age
        self.onLogOut = onLogOut
        self.onPhotoChanged = onPhotoChanged
        _displayedImage = State(initialValue: avatarImage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                recentlyPlayedSection
                    .padding(.horizontal, 20)
                VStack(spacing: 16) {
                    identityCard
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
                NavigationLink {
                    AddFriendsView()
                } label: {
                    Image(systemName: "person.fill.badge.plus")
                }
                .accessibilityLabel("Add friends")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileSettingsView(
                        profile: profile,
                        email: email,
                        joinedAt: joinedAt,
                        age: age,
                        selectedPhoto: $selectedPhoto,
                        isUpdatingPhoto: isUpdatingPhoto,
                        onLogOut: onLogOut
                    )
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await updatePhoto(from: item) }
        }
        .task {
            await loadPlaylists()
            await loadRecentlyPlayed()
        }
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
                    Color(red: 0.10, green: 0.10, blue: 0.10)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 180, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.custom("BowlbyOne-Regular", size: 27, relativeTo: .largeTitle))
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
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
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.8), radius: 5, y: 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height + pullDistance)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0
            ))
            .offset(y: -pullDistance)
        }
        .frame(height: 460)
    }

    private var identityCard: some View {
        friendsContent.profileGlassCard(cornerRadius: 16)
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Recently played")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                if recentlyPlayed.count > 3 {
                    Button(showsAllRecent ? "Show less" : "See more") {
                        withAnimation(.easeInOut(duration: 0.25)) { showsAllRecent.toggle() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }

            if isLoadingRecentlyPlayed {
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in musicSkeletonRow(artworkSize: 58) }
                }
            } else if recentNeedsPermission && recentlyPlayed.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Spotify needs one-time approval to show your listening history. Your WhoListens account stays signed in.")
                        .foregroundStyle(.white.opacity(0.6))
                    if let recentError {
                        Text(recentError)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Button(isConnectingSpotify ? "Opening Spotify…" : "Approve in Spotify") {
                        Task { await connectSpotify() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isConnectingSpotify)
                }
                .font(.system(size: 14))
            } else if recentlyPlayed.isEmpty, let recentError {
                HStack {
                    Text(recentError)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button("Retry") { Task { await loadRecentlyPlayed(forceRefresh: true) } }
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
            } else if recentlyPlayed.isEmpty {
                Text("Your recently played songs will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                VStack(spacing: 16) {
                    ForEach(showsAllRecent ? recentlyPlayed : Array(recentlyPlayed.prefix(3))) { item in
                        Button {
                            if let url = item.track.spotifyURL { openURL(url) }
                        } label: {
                            recentlyPlayedRow(item)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.track.spotifyURL == nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func recentlyPlayedRow(_ item: SpotifyRecentlyPlayedItem) -> some View {
        HStack(spacing: 12) {
            SpotifyCachedArtwork(url: item.track.artworkURL, size: 58, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.track.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.track.artistNames)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(playbackTimeLabel(for: item.playedAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(white: 0.24), in: Capsule())
        }
        .contentShape(Rectangle())
    }

    private func playbackTimeLabel(for date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 { return "Just now" }
        if elapsed < 3_600 { return "\(Int(elapsed / 60)) min ago" }
        if elapsed < 86_400 { return "\(Int(elapsed / 3_600)) hr ago" }
        if elapsed < 604_800 { return "\(Int(elapsed / 86_400)) days ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func musicSkeletonRow(artworkSize: CGFloat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.12))
                .frame(width: artworkSize, height: artworkSize)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(.white.opacity(0.13)).frame(width: 120, height: 13)
                Capsule().fill(.white.opacity(0.08)).frame(width: 170, height: 10)
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var friendsContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
            Text("0 friends")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR MUSIC")
                .font(AppTypography.title)
            if isLoadingPlaylists {
                VStack(spacing: 13) {
                    ForEach(0..<3, id: \.self) { _ in musicSkeletonRow(artworkSize: 48) }
                }
                .padding(.vertical, 8)
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
            SpotifyCachedArtwork(url: playlist.artworkURL, size: 48, cornerRadius: 8)

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
            SpotifyCachedArtwork(url: track.artworkURL, size: 48, cornerRadius: 8)
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
    private func loadPlaylists(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let cachedPlaylists = SpotifyProfilePreload.shared.playlists(for: profile.id),
           let cachedSavedTracks = SpotifyProfilePreload.shared.savedTracks(for: profile.id) {
            playlists = cachedPlaylists
            savedTracks = cachedSavedTracks
            playlistNeedsConnection = false
            playlistError = nil
            savedTracksError = nil
            savedTracksNeedsConnection = false
            isLoadingPlaylists = false
            return
        }
        isLoadingPlaylists = playlists.isEmpty && savedTracks.isEmpty
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
    private func loadRecentlyPlayed(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let cached = SpotifyProfilePreload.shared.recentlyPlayed(for: profile.id) {
            recentlyPlayed = cached
            recentNeedsPermission = false
            recentError = nil
            isLoadingRecentlyPlayed = false
            return
        }
        isLoadingRecentlyPlayed = recentlyPlayed.isEmpty
        recentError = nil
        defer { isLoadingRecentlyPlayed = false }
        do {
            let token: String?
            if let nativeToken = try await SpotifyAppAuthenticator.shared.accessToken() {
                token = nativeToken
            } else {
                token = try await supabase.auth.session.providerToken
            }
            guard let token else {
                recentNeedsPermission = true
                await upgradeRecentPermissionOnce()
                return
            }
            try await fetchRecentlyPlayed(token: token)
            if recentNeedsPermission {
                await upgradeRecentPermissionOnce()
            }
        } catch SpotifyRecentlyPlayedError.unavailable(let message) {
            recentNeedsPermission = false
            recentError = message
        } catch {
            recentError = "Could not load recent music."
        }
    }

    @MainActor
    private func upgradeRecentPermissionOnce() async {
        let userID = profile.id.uuidString
        guard recentUpgradeAttemptedForUserID != userID else { return }
        recentUpgradeAttemptedForUserID = userID
        await connectSpotify()
    }

    @MainActor
    private func fetchRecentlyPlayed(token: String) async throws {
        do {
            recentlyPlayed = try await SpotifyRecentlyPlayedService.recent(providerToken: token)
            recentNeedsPermission = false
            recentError = nil
        } catch SpotifyRecentlyPlayedError.permissionRequired {
            recentNeedsPermission = true
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
            try? await fetchPlaylists(token: token)
            do {
                try await fetchRecentlyPlayed(token: token)
            } catch {
                recentNeedsPermission = false
                recentError = "Could not load recent music."
            }
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                playlistError = "Could not connect to Spotify. Please try again."
                if recentNeedsPermission {
                    recentError = "Spotify could not approve listening history. Try again."
                }
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
    func profileGlassCard(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
        }
    }
}
