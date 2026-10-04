import SwiftUI

struct ContentView: View {
    private enum SessionState { case loading, signedIn, signedOut }

    @State private var sessionState: SessionState = .loading
    @AppStorage("hasAuthenticatedBefore") private var hasAuthenticatedBefore = false
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0

    var body: some View {
        Group {
            switch sessionState {
            case .loading:
                Color.black.ignoresSafeArea()
                    .overlay { ProgressView().tint(.white) }
            case .signedIn:
                SignedInOnboardingView()
            case .signedOut:
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) { AppToastOverlay() }
        .task {
            for await (event, session) in supabase.auth.authStateChanges {
                if event == .signedOut || event == .userDeleted {
                    savedName = ""
                    pendingBirthMonth = 0
                    pendingBirthYear = 0
                    sessionState = .signedOut
                } else if let session, !session.isExpired {
                    hasAuthenticatedBefore = true
                    sessionState = .signedIn
                } else if event == .initialSession {
                    if let refreshed = try? await supabase.auth.session, !refreshed.isExpired {
                        hasAuthenticatedBefore = true
                        sessionState = .signedIn
                    } else {
                        sessionState = .signedOut
                    }
                } else {
                    sessionState = .signedOut
                }
            }
        }
    }
}

private struct SignedInOnboardingView: View {
    private enum Destination { case loading, profileDetails, settingUp, home, failed }

    @State private var destination: Destination = .loading
    @State private var homeProfile: Profile?
    @State private var homeAvatarImage: UIImage?
    @State private var homeEmail: String?
    @State private var homeJoinedAt: Date?
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0

    var body: some View {
        Group {
            if case .home = destination, let homeProfile {
                HomeView(
                    preloadedProfile: homeProfile,
                    preloadedAvatarImage: homeAvatarImage,
                    preloadedEmail: homeEmail,
                    preloadedJoinedAt: homeJoinedAt
                )
            } else {
                NavigationStack {
                    ZStack {
                        onboardingContent
                            .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: 0.25), value: destination)
                }
            }
        }
        .task { await loadProfile() }
    }

    @ViewBuilder
    private var onboardingContent: some View {
        switch destination {
        case .loading:
            Color.black.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
        case .profileDetails:
            AgeConfirmationView(onFinished: { destination = .settingUp })
        case .settingUp:
            SettingUpView(onComplete: saveProfile, onStartOver: resetDeletedAccount)
        case .home:
            EmptyView()
        case .failed:
            VStack(spacing: 16) {
                Text("We couldn't load your profile.")
                Button("Try again") { Task { await loadProfile() } }
                    .buttonStyle(PrimaryActionStyle())
            }
            .padding(24)
        }
    }

    @MainActor
    private func loadProfile() async {
        destination = .loading
        do {
            let session = try await supabase.auth.session
            // A session cached on the device can survive deletion of its Auth
            // user. Validate it against Auth before using it to load a profile.
            guard let user = try? await supabase.auth.user() else {
                throw OnboardingAccountError()
            }
            guard user.id == session.user.id else { throw OnboardingAccountError() }
            let existing: Profile? = try await supabase.from("profiles")
                .select("id, display_name, birth_month, birth_year, avatar_path")
                .eq("id", value: session.user.id.uuidString)
                .maybeSingle()
                .execute()
                .value
            if let existing {
                await SpotifyProfilePreload.shared.preload(for: existing.id)
                homeAvatarImage = if let path = existing.avatarPath {
                    try? await ProfilePhotoService.download(path: path)
                } else {
                    nil
                }
                homeEmail = session.user.email
                homeJoinedAt = session.user.createdAt
                homeProfile = existing
                destination = .home
            } else {
                destination = .profileDetails
            }
        } catch {
            if error is OnboardingAccountError {
                await resetDeletedAccount()
            } else {
                destination = .failed
            }
        }
    }

    @MainActor
    private func saveProfile() async throws {
        let name = String(savedName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard !name.isEmpty, (1...12).contains(pendingBirthMonth), pendingBirthYear >= 1900 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let session = try await supabase.auth.session
        guard let user = try? await supabase.auth.user() else {
            throw OnboardingAccountError()
        }
        guard user.id == session.user.id else { throw OnboardingAccountError() }
        var profile: Profile = try await supabase.from("profiles")
            .upsert(OnboardingProfile(
                id: session.user.id,
                displayName: name,
                birthMonth: pendingBirthMonth,
                birthYear: pendingBirthYear
            ))
            .select("id, display_name, birth_month, birth_year, avatar_path")
            .single()
            .execute()
            .value
        // Photo is optional. HomeView can retry upload if it fails here.
        if let path = try? await ProfilePhotoService.uploadPending(for: profile.id) {
            profile = Profile(
                id: profile.id,
                displayName: profile.displayName,
                birthMonth: profile.birthMonth,
                birthYear: profile.birthYear,
                avatarPath: path
            )
        }
        pendingBirthMonth = 0
        pendingBirthYear = 0
        await SpotifyProfilePreload.shared.preload(for: profile.id)
        homeAvatarImage = if let path = profile.avatarPath {
            try? await ProfilePhotoService.download(path: path)
        } else {
            nil
        }
        homeEmail = session.user.email
        homeJoinedAt = session.user.createdAt
        homeProfile = profile
        destination = .home
    }

    @MainActor
    private func resetDeletedAccount() async {
        savedName = ""
        pendingBirthMonth = 0
        pendingBirthYear = 0
        SpotifyAppAuthenticator.shared.clearSession()
        try? await supabase.auth.signOut(scope: .local)
    }
}

struct OnboardingAccountError: Error {}

private struct OnboardingProfile: Encodable {
    let id: UUID
    let displayName: String
    let birthMonth: Int
    let birthYear: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthMonth = "birth_month"
        case birthYear = "birth_year"
    }
}
