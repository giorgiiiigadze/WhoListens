import AuthenticationServices
import PhotosUI
import SwiftUI

struct ProfileView: View {
    let profile: Profile
    let email: String?
    let joinedAt: Date?
    let age: Int?
    let isLoadingPhoto: Bool
    let onLogOut: (() -> Void)?
    let onPhotoChanged: () async throws -> Void
    let onProfileChanged: () async -> Void

    @Environment(\.openURL) private var openURL
    @Binding private var displayedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var photoError: String?
    @State private var photoSkeletonPulse = false
    @State private var playlists: [SpotifyPlaylist] = []
    @State private var savedTracks: [SpotifySavedTrack] = []
    @State private var savedTracksError: String?
    @State private var savedTracksNeedsConnection = false
    @State private var isLoadingPlaylists = true
    @State private var isConnectingSpotify = false
    @State private var playlistNeedsConnection = false
    @State private var playlistError: String?
    @State private var recentlyPlayed: [SpotifyRecentlyPlayedItem] = []
    @State private var topArtists: [SpotifyTopArtist] = []
    @State private var topTracks: [SpotifySavedTrack] = []
    @State private var isLoadingTopArtists = true
    @State private var isLoadingTopTracks = true
    @State private var topArtistsError: String?
    @State private var topTracksError: String?
    @State private var isLoadingRecentlyPlayed = true
    @State private var recentNeedsPermission = false
    @State private var recentError: String?
    @State private var showsAllRecent = false
    @State private var friendCount = 0

    init(
        profile: Profile,
        avatarImage: Binding<UIImage?>,
        email: String?,
        joinedAt: Date?,
        age: Int?,
        isLoadingPhoto: Bool,
        onLogOut: (() -> Void)? = nil,
        onPhotoChanged: @escaping () async throws -> Void,
        onProfileChanged: @escaping () async -> Void = {}
    ) {
        self.profile = profile
        self.email = email
        self.joinedAt = joinedAt
        self.age = age
        self.isLoadingPhoto = isLoadingPhoto
        self.onLogOut = onLogOut
        self.onPhotoChanged = onPhotoChanged
        self.onProfileChanged = onProfileChanged
        _displayedImage = avatarImage
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                hero
                identityCard
                    .padding(.horizontal, 20)
                recentlyPlayedSection
                    .padding(.horizontal, 20)
                rediscoverSection
                    .padding(.bottom, 32)
            }
        }
        .coordinateSpace(name: "profileScroll")
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .ignoresSafeArea(edges: .top)
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
                        isUpdatingPhoto: $isUpdatingPhoto,
                        onLogOut: onLogOut,
                        avatarImage: $displayedImage,
                        photoError: $photoError,
                        onProfileChanged: onProfileChanged
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
            await loadFriendCount()
            await SpotifyProfilePreload.shared.preload(for: profile.id)
            await loadPlaylists()
            await loadRecentlyPlayed()
            await loadTopArtists()
            await loadTopTracks()
        }
        .refreshable {
            await loadFriendCount()
            await loadRecentlyPlayed(forceRefresh: true)
            await loadTopArtists(forceRefresh: true)
            await loadTopTracks(forceRefresh: true)
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
                } else if isLoadingPhoto {
                    Rectangle()
                        .fill(Color(white: 0.19))
                        .opacity(photoSkeletonPulse ? 0.57 : 1)
                        .onAppear {
                            photoSkeletonPulse = false
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                photoSkeletonPulse = true
                            }
                        }
                } else {
                    Color(red: 0.10, green: 0.10, blue: 0.10)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 180, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: .black.opacity(0.12), location: 0.78),
                        .init(color: .black.opacity(0.52), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

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
                .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
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

    private var rediscoverSection: some View {
        VStack(spacing: 22) {
            VStack(spacing: 2) {
                Text("Rediscover")
                    .font(.custom("BowlbyOne-Regular", size: 24, relativeTo: .title2))
                Text("Your first recap")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 20)

            recapHeading("top artists", colors: [Color(red: 0.47, green: 0.40, blue: 0.79), Color(red: 0.27, green: 0.22, blue: 0.48)])
            recapArtists
                .padding(.top, -49)
            recapHeading("on repeat", colors: [Color(red: 0.82, green: 0.34, blue: 0.25), Color(red: 0.47, green: 0.16, blue: 0.13)])
            recapTracks
                .padding(.top, -45)

            Color.clear
                .frame(height: 48)
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.15), Color(red: 0.20, green: 0.15, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 32)
        )
    }

    private func recapHeading(_ title: String, colors: [Color]) -> some View {
        Text(title)
            .font(.custom("BowlbyOne-Regular", size: 54, relativeTo: .largeTitle))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
    }

    private var recapArtists: some View {
        return Group {
            if isLoadingTopArtists {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) { ForEach(0..<3, id: \.self) { _ in artistSkeleton.frame(width: 106) } }
                        .padding(.horizontal, 20)
                }
            } else if let topArtistsError {
                Button(topArtistsError) { Task { await loadTopArtists(forceRefresh: true) } }
                    .font(.system(size: 14))
                    .padding(.vertical, 42)
            } else if topArtists.isEmpty {
                Text("Your top artists will appear here as you listen on Spotify.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center).padding(.vertical, 42).padding(.horizontal, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(topArtists.enumerated()), id: \.element.id) { index, artist in
                            VStack(spacing: 10) {
                                SpotifyCachedArtwork(url: artist.artworkURL, size: 104, cornerRadius: 52)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(width: 35, height: 35)
                                            .background(Color(red: 0.45, green: 0.37, blue: 0.73), in: Circle())
                                            .overlay(Circle().stroke(Color(white: 0.15), lineWidth: 3))
                                    }
                                Text(artist.name).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                            }.frame(width: 112)
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }

    private var recapTracks: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingTopTracks {
                HStack(spacing: 13) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.12))
                            .frame(width: 126, height: 126)
                    }
                }
                .padding(.horizontal, 20)
            } else if let topTracksError {
                Button(topTracksError) { Task { await loadTopTracks(forceRefresh: true) } }
                    .font(.system(size: 14))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 42)
            } else if topTracks.isEmpty {
                Text("Your top tracks will appear here as you listen on Spotify.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 42)
            } else {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 13) {
                    ForEach(topTracks) { track in
                        VStack(alignment: .leading, spacing: 7) {
                            SpotifyCachedArtwork(url: track.artworkURL, size: 126, cornerRadius: 2)
                            Text(track.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text(track.artistNames).font(.system(size: 13)).foregroundStyle(.white.opacity(0.58)).lineLimit(1)
                        }.frame(width: 126, alignment: .leading)
                    }
                }.padding(.horizontal, 20)
              }
            }
        }.padding(.top, 4)
    }

    private var artistSkeleton: some View {
        VStack(spacing: 10) {
            Circle().fill(.white.opacity(0.12)).frame(width: 92, height: 92)
            Capsule().fill(.white.opacity(0.12)).frame(width: 70, height: 13)
        }.frame(maxWidth: .infinity)
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
            Text("\(friendCount) \(friendCount == 1 ? "friend" : "friends")")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }

    @MainActor
    private func loadFriendCount() async {
        guard let connections = try? await FriendsService.connections() else { return }
        friendCount = connections.filter { $0.status == .accepted }.count
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
            let token = try await SpotifyAccessService.shared.accessToken()
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
            let token = try await SpotifyAccessService.shared.accessToken()
            guard let token else {
                recentNeedsPermission = true
                return
            }
            try await fetchRecentlyPlayed(token: token)
        } catch SpotifyRecentlyPlayedError.unavailable(let message) {
            recentNeedsPermission = false
            recentError = message
        } catch {
            recentError = "Could not load recent music."
        }
    }

    @MainActor
    private func loadTopArtists(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let cached = SpotifyProfilePreload.shared.topArtists(for: profile.id) {
            topArtists = cached
            topArtistsError = nil
            isLoadingTopArtists = false
            return
        }
        isLoadingTopArtists = topArtists.isEmpty
        topArtistsError = nil
        defer { isLoadingTopArtists = false }
        do {
            guard let token = try await SpotifyAccessService.shared.accessToken() else {
                topArtistsError = "Spotify music is unavailable. Tap to retry."
                return
            }
            try await fetchTopArtists(token: token)
        } catch SpotifyTopArtistError.permissionRequired {
            topArtistsError = "Spotify has not granted top artists access."
        } catch {
            topArtistsError = "Couldn’t load top artists. Tap to retry."
        }
    }

    @MainActor
    private func loadTopTracks(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = SpotifyProfilePreload.shared.topTracks(for: profile.id) {
            topTracks = cached
            topTracksError = nil
            isLoadingTopTracks = false
            return
        }
        isLoadingTopTracks = topTracks.isEmpty
        topTracksError = nil
        defer { isLoadingTopTracks = false }
        do {
            guard let token = try await SpotifyAccessService.shared.accessToken() else {
                topTracksError = "Spotify music is unavailable. Tap to retry."
                return
            }
            let tracks = try await SpotifyTopTrackService.topTracks(providerToken: token)
            topTracks = tracks
            SpotifyProfilePreload.shared.storeTopTracks(tracks, for: profile.id)
        } catch SpotifyTopTrackError.permissionRequired {
            topTracksError = "Spotify has not granted top tracks access."
        } catch {
            topTracksError = "Couldn’t load top tracks. Tap to retry."
        }
    }

    @MainActor
    private func fetchTopArtists(token: String) async throws {
        let artists = try await SpotifyTopArtistService.topArtists(providerToken: token)
        topArtists = artists
        SpotifyProfilePreload.shared.storeTopArtists(artists, for: profile.id)
        topArtistsError = nil
    }

    @MainActor
    private func fetchRecentlyPlayed(token: String) async throws {
        do {
            recentlyPlayed = try await SpotifyRecentlyPlayedService.recent(providerToken: token)
            SpotifyProfilePreload.shared.storeRecentlyPlayed(recentlyPlayed, for: profile.id)
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
            let token = try await SpotifyAccessService.shared.connect()
            try? await fetchPlaylists(token: token)
            do {
                try await fetchTopArtists(token: token)
            } catch SpotifyTopArtistError.permissionRequired {
                // Listening history remains available for the recap.
            } catch {
                topArtistsError = "Couldn’t load top artists. Tap to retry."
            }
            do {
                try await fetchRecentlyPlayed(token: token)
            } catch {
                recentNeedsPermission = false
                recentError = "Could not load recent music."
            }
            await loadTopTracks(forceRefresh: true)
            AppToastCenter.shared.show("Spotify is connected.", style: .success)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                playlistError = "Could not connect to Spotify. Please try again."
                AppToastCenter.shared.show("Could not connect to Spotify.", style: .error)
                if recentNeedsPermission {
                    recentError = "Spotify could not approve listening history. Try again."
                }
            }
        }
    }

    @MainActor
    private func updatePhoto(from item: PhotosPickerItem) async {
        isUpdatingPhoto = true
        defer {
            isUpdatingPhoto = false
            selectedPhoto = nil
        }
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
            AppToastCenter.shared.show("Profile photo updated.", style: .success)
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
