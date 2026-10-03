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
    case home, play, music, profile
}

struct HomeView: View {
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
    @ObservedObject private var artworkStore = SpotifyArtworkStore.shared
    @AppStorage("lastRoomCode") private var lastRoomCode = ""

    private let background = AppColors.background

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
                PlayTabView()
            }
            .tabItem { Label("Play", systemImage: "gamecontroller.fill") }
            .tag(MainTab.play)

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
        .task { await loadProfile() }
    }

    private var homePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if isLoading {
                    ProgressView("Getting your space ready…")
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let profileError {
                    VStack(spacing: 14) {
                        Text(profileError)
                        Button("Try again") { Task { await loadProfile() } }
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else if let profile {
                    Text("Hey, \(profile.displayName).")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    partyHero

                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeading("Your space", subtitle: "Pick up wherever the music takes you.")
                        HStack(spacing: 12) {
                            shortcut(title: "Play", detail: "Join a room", symbol: "person.2.fill", tint: AppColors.mintAccent) {
                                selectedTab = .play
                            }
                            shortcut(title: "Music", detail: "Your library", symbol: "music.note", tint: Color(red: 0.20, green: 0.80, blue: 0.56)) {
                                selectedTab = .music
                            }
                        }
                    }

                    if !lastRoomCode.isEmpty {
                        Button { selectedTab = .play } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppColors.warmOrange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your last room").font(.system(size: 17, weight: .semibold))
                                    Text("Code \(lastRoomCode) · Tap to resume")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(18)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }

                    musicPreview
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .background(background.ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .task { await artworkStore.preload() }
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
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
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

    private var partyHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30)
                .fill(LinearGradient(
                    colors: [Color(red: 0.25, green: 0.21, blue: 0.49), Color(red: 0.12, green: 0.39, blue: 0.39), Color(red: 0.08, green: 0.30, blue: 0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 24)
                .frame(width: 210, height: 210)
                .offset(x: 210, y: -62)

            VStack(alignment: .leading, spacing: 16) {
                Label("THE GOOD PART", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.85))

                Text("Your music.\nYour people.")
                    .font(.system(size: 33, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Make a room and see who knows your taste best.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.87))

                Button { selectedTab = .play } label: {
                    HStack(spacing: 8) {
                        Text("Let’s play")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
            }
            .padding(26)
        }
        .frame(maxWidth: .infinity, minHeight: 285, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private var musicPreview: some View {
        Button { selectedTab = .music } label: {
            HStack(spacing: 16) {
                HStack(spacing: -26) {
                    ForEach(0..<3, id: \.self) { index in
                        Group {
                            if artworkStore.images.indices.contains(index), let image = artworkStore.images[index] {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Image(systemName: "music.note")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(AppColors.electricPurple)
                            }
                        }
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(background, lineWidth: 3))
                    }
                }
                .frame(width: 152)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Your music")
                        .font(.system(size: 18, weight: .bold))
                    Text("Playlists & saved songs")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 23, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.58))
        }
    }

    private func shortcut(title: String, detail: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(height: 36)
                Spacer(minLength: 2)
                Text(title).font(.system(size: 19, weight: .bold))
                Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 118)
            .padding(18)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
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
            await ProfilePhotoService.cleanupReplacedPhotos(for: loaded.id)
            try? await refreshPhoto()
            if let avatarPath = profile?.avatarPath {
                avatarImage = try? await ProfilePhotoService.download(path: avatarPath)
            } else {
                avatarImage = nil
            }
            isLoadingPhoto = false
        } catch {
            profileError = "We couldn't load your profile."
            isLoadingPhoto = false
        }
        isLoading = false
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
        SpotifyProfilePreload.shared.clear()
        PendingProfilePhoto.clear()
        try? await supabase.auth.signOut(scope: .local)
        isSigningOut = false
    }
}
