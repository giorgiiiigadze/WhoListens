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
                AppColors.background.ignoresSafeArea()
                    .overlay { ProgressView().tint(.white) }
            case .signedIn:
                SignedInOnboardingView()
            case .signedOut:
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
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
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0

    var body: some View {
        Group {
            if case .home = destination {
                HomeView()
            } else {
                NavigationStack {
                    onboardingContent
                }
            }
        }
        .task { await loadProfile() }
    }

    @ViewBuilder
    private var onboardingContent: some View {
        switch destination {
        case .loading:
            AppColors.background.ignoresSafeArea()
                .overlay { ProgressView().tint(.white) }
        case .profileDetails:
            AgeConfirmationView(onFinished: { destination = .settingUp })
        case .settingUp:
            SettingUpView(onComplete: saveProfile)
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
            let existing: Profile? = try await supabase.from("profiles")
                .select("id, display_name, birth_month, birth_year, avatar_path")
                .eq("id", value: session.user.id.uuidString)
                .maybeSingle()
                .execute()
                .value
            if let existing {
                await SpotifyProfilePreload.shared.preload(for: existing.id)
                destination = .home
            } else {
                destination = .profileDetails
            }
        } catch {
            destination = .failed
        }
    }

    @MainActor
    private func saveProfile() async throws {
        let name = String(savedName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard !name.isEmpty, (1...12).contains(pendingBirthMonth), pendingBirthYear >= 1900 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let session = try await supabase.auth.session
        let profile: Profile = try await supabase.from("profiles")
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
        _ = try? await ProfilePhotoService.uploadPending(for: profile.id)
        pendingBirthMonth = 0
        pendingBirthYear = 0
        await SpotifyProfilePreload.shared.preload(for: profile.id)
        destination = .home
    }
}

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
