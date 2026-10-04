import SwiftUI

struct Profile: Decodable {
    let id: UUID
    let displayName: String
    let birthMonth: Int
    let birthYear: Int
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthMonth = "birth_month"
        case birthYear = "birth_year"
        case avatarPath = "avatar_path"
    }
}

private enum MainTab: Hashable {
    case home, friends, music, profile
}

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: MainTab = .home
    @State private var profile: Profile?
    @State private var avatarImage: UIImage?
    @State private var isLoadingPhoto = false
    @State private var email: String?
    @State private var joinedAt: Date?
    @State private var isLoading = true
    @State private var profileError: String?
    @State private var isSigningOut = false
    @State private var profileSkeletonPulse = false
    @State private var homeSkeletonPulse = false
    @State private var showJoinGame = false
    @State private var activeRoom: GameRoom?
    @State private var isCreatingRoom = false
    @State private var partyError: String?
    @State private var albumArtworkURLs: [URL] = []
    @AppStorage("lastRoomCode") private var lastRoomCode = ""

    private let background = Color.black

    init(
        preloadedProfile: Profile,
        preloadedAvatarImage: UIImage?,
        preloadedEmail: String?,
        preloadedJoinedAt: Date?
    ) {
        _profile = State(initialValue: preloadedProfile)
        _avatarImage = State(initialValue: preloadedAvatarImage)
        _email = State(initialValue: preloadedEmail)
        _joinedAt = State(initialValue: preloadedJoinedAt)
        _isLoading = State(initialValue: false)
        _albumArtworkURLs = State(initialValue: Self.albumCovers(for: preloadedProfile.id))
    }

    private var age: Int? {
        guard let profile else { return nil }
        let today = Date()
        let calendar = Calendar.current
        return calendar.component(.year, from: today) - profile.birthYear
            - (calendar.component(.month, from: today) < profile.birthMonth ? 1 : 0)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                homePage
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(MainTab.home)

            NavigationStack {
                FriendsTabView(displayName: profile?.displayName ?? "", avatarImage: avatarImage)
            }
            .tabItem { Label("Friends", systemImage: "person.2.fill") }
            .tag(MainTab.friends)

            NavigationStack {
                MusicTabView()
            }
            .tabItem { Label("Music", systemImage: "music.note.list") }
            .tag(MainTab.music)

            NavigationStack {
                if let profile {
                    ProfileView(
                        profile: profile,
                        avatarImage: $avatarImage,
                        email: email,
                        joinedAt: joinedAt,
                        age: age,
                        isLoadingPhoto: isLoadingPhoto,
                        onLogOut: { Task { await logOut() } },
                        onPhotoChanged: refreshPhoto,
                        onProfileChanged: loadProfile
                    )
                } else {
                    loadingProfile
                }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(MainTab.profile)
        }
        .tint(.white)
        .toolbarBackground(background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .task(id: selectedTab) {
            guard selectedTab == .home, let profile else { return }
            await SpotifyProfilePreload.shared.preload(for: profile.id)
            albumArtworkURLs = Self.albumCovers(for: profile.id)
        }
        .task(id: profile?.id) {
            guard let profile, avatarImage == nil else { return }
            let fallback = await SpotifyProfileImageService.image(for: profile.id)
            guard self.profile?.id == profile.id, avatarImage == nil else { return }
            avatarImage = fallback
        }
    }

    private var homePage: some View {
        ZStack {
            AlbumMotionBackground(urls: albumArtworkURLs, reduceMotion: reduceMotion)

            VStack(spacing: 18) {
                if isLoading {
                    homeSkeleton
                } else {
                    header

                    if let profileError {
                        Spacer()
                        VStack(spacing: 14) {
                            Text(profileError)
                            Button("Try again") { Task { await loadProfile() } }
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    } else if let profile {
                        Spacer(minLength: 24)
                        partyHero(profile: profile)
                        Spacer(minLength: 24)

                        if !lastRoomCode.isEmpty {
                            Button { selectedTab = .friends } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundStyle(AppColors.warmOrange)
                                    Text("Your last room · \(lastRoomCode)")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(15)
                                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }

                        partyActions
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)
        }
        .background(background.ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showJoinGame) { JoinGameView() }
        .navigationDestination(item: $activeRoom) { room in
            RoomSessionView(room: room)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var loadingProfile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    Color(white: 0.16)
                    VStack(alignment: .leading, spacing: 10) {
                        skeletonBar(width: 164, height: 28)
                        skeletonBar(width: 190, height: 15)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                .frame(height: 460)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 28,
                    bottomTrailingRadius: 28,
                    topTrailingRadius: 0
                ))

                skeletonBar(width: nil, height: 46)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 16) {
                    skeletonBar(width: 126, height: 15)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(white: 0.20))
                                .frame(width: 58, height: 58)
                            VStack(alignment: .leading, spacing: 9) {
                                skeletonBar(width: 170, height: 14)
                                skeletonBar(width: 116, height: 12)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(white: 0.16))
                    .frame(height: 320)
                    .padding(.bottom, 32)
            }
            .opacity(profileSkeletonPulse ? 0.62 : 1)
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            profileSkeletonPulse = false
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                profileSkeletonPulse = true
            }
        }
    }

    private func skeletonBar(width: CGFloat?, height: CGFloat) -> some View {
        Capsule()
            .fill(Color(white: 0.23))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text("Who Listens?")
                .font(AppTypography.title)
            Spacer()
            Button { selectedTab = .profile } label: {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage).resizable().scaledToFill()
                    } else {
                        Text(AvatarInitials.forName(profile?.displayName ?? ""))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.electricPurple)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
    }

    private func partyHero(profile: Profile) -> some View {
        VStack(spacing: 12) {
            Group {
                if let avatarImage {
                    Image(uiImage: avatarImage).resizable().scaledToFill()
                } else {
                    Text(AvatarInitials.forName(profile.displayName))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.electricPurple.opacity(0.55))
                }
            }
            .frame(width: 116, height: 116)
            .clipShape(Circle())

            Text("@\(profile.displayName)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
        .frame(width: 186, height: 230)
        .background(Color(white: 0.12).opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
        .frame(maxWidth: .infinity)
    }

    private var homeSkeleton: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Who Listens?")
                    .font(AppTypography.title)
                Spacer()
                Circle()
                    .fill(.white.opacity(0.17))
                    .frame(width: 44, height: 44)
            }

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 116, height: 116)
                Capsule()
                    .fill(.white.opacity(0.16))
                    .frame(width: 148, height: 18)
            }
            .frame(width: 186, height: 230)
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 22))
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            if !lastRoomCode.isEmpty {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.12))
                    .frame(height: 50)
            }

            VStack(spacing: 7) {
                Capsule().fill(.white.opacity(0.12)).frame(width: 250, height: 13)
                Capsule().fill(.white.opacity(0.12)).frame(width: 195, height: 13)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 17)
                    .fill(.white.opacity(0.16))
                    .frame(height: 62)
                RoundedRectangle(cornerRadius: 17)
                    .fill(.white.opacity(0.12))
                    .frame(height: 62)
            }
        }
        .opacity(homeSkeletonPulse ? 0.55 : 1)
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                homeSkeletonPulse = true
            }
        }
    }

    private var partyActions: some View {
        VStack(spacing: 10) {
            Text("Join your friend's game with their PIN, or start your own.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.bottom, 8)

            Button { showJoinGame = true } label: {
                Text("Join a party")
                    .font(AppTypography.body)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(LinearGradient(
                        stops: [
                            .init(color: Color(red: 203 / 255, green: 3 / 255, blue: 3 / 255), location: 0),
                            .init(color: Color(red: 0.47, green: 0.16, blue: 0.13), location: 0.32),
                            .init(color: Color(red: 0.82, green: 0.34, blue: 0.25), location: 0.72),
                            .init(color: Color(red: 0.47, green: 0.16, blue: 0.13), location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ), in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)

            Button { Task { await createRoom() } } label: {
                Group {
                    if isCreatingRoom { ProgressView().tint(.black) }
                    else { Text("Create a party") }
                }
                .font(AppTypography.body)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(.white, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)
            .disabled(isCreatingRoom)

            if let partyError {
                Text(partyError)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @MainActor
    private func createRoom() async {
        guard !isCreatingRoom else { return }
        isCreatingRoom = true
        defer { isCreatingRoom = false }
        do {
            let room = try await GameBackend.create()
            lastRoomCode = room.code
            partyError = nil
            activeRoom = room
            AppToastCenter.shared.show("Party created. Share your PIN!", style: .success)
        } catch {
            partyError = "Could not create a party. Please try again."
            AppToastCenter.shared.show("Could not create a party. Please try again.", style: .error)
        }
    }

    @MainActor
    private func loadProfile() async {
        isLoading = true
        profileError = nil
        do {
            let session = try await supabase.auth.session
            email = session.user.email
            joinedAt = session.user.createdAt
            let loaded: Profile = try await supabase.from("profiles")
                .select("id, display_name, birth_month, birth_year, avatar_path")
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            isLoadingPhoto = loaded.avatarPath != nil
            profile = loaded
            albumArtworkURLs = Self.albumCovers(for: loaded.id)
            Task {
                await SpotifyProfilePreload.shared.preload(for: loaded.id)
                guard profile?.id == loaded.id else { return }
                albumArtworkURLs = Self.albumCovers(for: loaded.id)
            }
            await ProfilePhotoService.cleanupReplacedPhotos(for: loaded.id)
            try? await refreshPhoto()
            if let avatarPath = profile?.avatarPath {
                avatarImage = try? await ProfilePhotoService.download(path: avatarPath)
            } else {
                avatarImage = nil
            }
            if avatarImage == nil {
                Task {
                    let fallback = await SpotifyProfileImageService.image(for: loaded.id)
                    guard self.profile?.id == loaded.id, avatarImage == nil else { return }
                    avatarImage = fallback
                }
            }
            isLoadingPhoto = false
        } catch {
            profileError = "We couldn't load your profile."
            isLoadingPhoto = false
        }
        isLoading = false
    }

    private static func albumCovers(for userID: UUID) -> [URL] {
        let recent = SpotifyProfilePreload.shared.recentlyPlayed(for: userID)?
            .compactMap(\.track.artworkURL) ?? []
        let saved = SpotifyProfilePreload.shared.savedTracks(for: userID)?
            .compactMap(\.artworkURL) ?? []
        var seen = Set<URL>()
        return (recent + saved).filter { seen.insert($0).inserted }.prefix(8).map { $0 }
    }

    @MainActor
    private func refreshPhoto() async throws {
        guard let profile else { return }
        if let path = try await ProfilePhotoService.uploadPending(for: profile.id, replacing: profile.avatarPath) {
            self.profile = Profile(
                id: profile.id,
                displayName: profile.displayName,
                birthMonth: profile.birthMonth,
                birthYear: profile.birthYear,
                avatarPath: path
            )
            avatarImage = try? await ProfilePhotoService.download(path: path)
        }
    }

    @MainActor
    private func logOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        SpotifyAppAuthenticator.shared.clearSession()
        SpotifyAccessService.shared.clear()
        SpotifyProfileImageService.clear()
        SpotifyProfilePreload.shared.clear()
        PendingProfilePhoto.clear()
        try? await supabase.auth.signOut(scope: .local)
        isSigningOut = false
    }
}

/// A few cached album covers drift slowly behind a dark scrim. Only their
/// position animates, so the screen avoids per-frame image processing.
private struct AlbumMotionBackground: View {
    let urls: [URL]
    let reduceMotion: Bool

    private let placements: [(x: CGFloat, y: CGFloat, direction: CGFloat)] = [
        (0.12, 0.16, 1), (0.84, 0.13, -1),
        (0.10, 0.47, -1), (0.91, 0.46, 1),
        (0.16, 0.60, 1), (0.84, 0.59, -1),
        (0.39, 0.70, -1), (0.67, 0.69, 1),
    ]

    var body: some View {
        GeometryReader { geometry in
            let coverSize = min(geometry.size.width * 0.27, 112)
            ZStack {
                Color.black

                ForEach(Array(urls.prefix(placements.count).enumerated()), id: \.offset) { index, url in
                    DriftingAlbumCover(
                        url: url,
                        size: coverSize,
                        direction: placements[index].direction,
                        reduceMotion: reduceMotion
                    )
                        .position(
                            x: geometry.size.width * placements[index].x,
                            y: geometry.size.height * placements[index].y
                        )
                }

                Color.black.opacity(0.48)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct DriftingAlbumCover: View {
    let url: URL
    let size: CGFloat
    let direction: CGFloat
    let reduceMotion: Bool

    @State private var drifting = false

    var body: some View {
        SpotifyCachedArtwork(url: url, size: size, cornerRadius: 14)
            .blur(radius: 1.5)
            .opacity(0.8)
            .offset(y: (drifting ? 28 : -28) * direction)
            .task(id: reduceMotion) {
                guard !reduceMotion else {
                    withTransaction(Transaction(animation: nil)) {
                        drifting = false
                    }
                    return
                }
                // Start after the cover's first frame. Keep the animation alive
                // across tab switches so it never snaps back to its start.
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    drifting = true
                }
            }
    }
}
