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

private struct NewProfile: Encodable {
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

struct HomeView: View {
    @AppStorage("hasAuthenticatedBefore") private var hasAuthenticatedBefore = false
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false

    @State private var profile: Profile?
    @State private var avatarImage: UIImage?
    @State private var email: String?
    @State private var joinedAt: Date?
    @State private var userID: UUID?
    @State private var isLoading = true
    @State private var profileLoadFailed = false
    @State private var isShowingProfile = false
    @State private var showJoinGame = false
    @State private var showCreateGame = false
    @State private var isSaving = false
    @State private var isSigningOut = false
    @State private var errorMessage: String?
    @State private var draftName = ""
    @State private var draftMonth = Calendar.current.component(.month, from: Date())
    @State private var draftYear = Calendar.current.component(.year, from: Date()) - 18

    private var age: Int? {
        guard let profile else { return nil }
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let month = Calendar.current.component(.month, from: now)
        return year - profile.birthYear - (month < profile.birthMonth ? 1 : 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    if isLoading {
                        Spacer(minLength: 80)
                        ProgressView("Loading profile…")
                            .tint(.white)
                        Spacer(minLength: 80)
                    } else if profileLoadFailed {
                        Spacer(minLength: 80)
                        Button("Retry loading profile") {
                            Task { await loadProfile() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .padding(18)
                        .background(.white.opacity(0.12), in: Capsule())
                        Spacer(minLength: 80)
                    } else if let profile {
                        Spacer(minLength: 48)
                        profileCard(profile)
                        Spacer(minLength: 48)
                        gameActions
                    } else {
                        setupForm
                            .padding(.top, 48)
                        Spacer(minLength: 40)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(homeBackground.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showJoinGame) {
            JoinGameView()
        }
        .navigationDestination(isPresented: $showCreateGame) {
            if hasSeenHowToPlay {
                GamePreviewView(mode: .create)
            } else {
                HowToPlayView(mode: .create)
            }
        }
        .fullScreenCover(isPresented: $isShowingProfile) {
            if let profile {
                NavigationStack {
                    ProfileView(
                        profile: profile,
                        avatarImage: avatarImage,
                        email: email,
                        joinedAt: joinedAt,
                        age: age,
                        onPhotoChanged: { try await refreshPhoto() }
                    )
                }
            }
        }
        .task { await loadProfile() }
    }

    private var homeBackground: some View {
        RadialGradient(
            colors: [Color(white: 0.11), .black],
            center: .center,
            startRadius: 20,
            endRadius: 420
        )
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { isShowingProfile = profile != nil } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .disabled(profile == nil)
            .accessibilityLabel("Open your profile")

            Text("My Friends  0")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))

            Menu {
                Button("Log out") { Task { await logOut() } }
                #if DEBUG
                Button("Show onboarding") { Task { await logOut(showOnboarding: true) } }
                #endif
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.25)))
            }
            .disabled(isSigningOut)
            .accessibilityLabel("Settings")
        }
    }

    private func profileCard(_ profile: Profile) -> some View {
        Button { isShowingProfile = true } label: {
            VStack(spacing: 14) {
                avatarThumbnail(size: 112)
                Text("@\(profile.displayName)")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(22)
            .frame(width: 220)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open your profile")
    }

    private var gameActions: some View {
        VStack(spacing: 14) {
            Text("Join your friend's game with their PIN, or start your own.")
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

            Button { showJoinGame = true } label: {
                Text("Join a game")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.76, blue: 0), AppColors.warmOrange, AppColors.hotPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
            }
            .buttonStyle(.plain)

            Button { showCreateGame = true } label: {
                Text("Create a party")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
    }

    private var setupForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Complete your profile")
                .font(.headline)

            TextField("Display name", text: $draftName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Text("Birth month and year")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            MonthYearPicker(month: $draftMonth, year: $draftYear)
                .frame(height: 160)

            Button {
                Task { await saveProfile() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save profile")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(isSaving || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppSpacing.medium)
        .foregroundStyle(.black)
        .background(.white, in: RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }

    @MainActor
    private func loadProfile() async {
        isLoading = true
        profileLoadFailed = false
        errorMessage = nil
        do {
            let session = try await supabase.auth.session
            email = session.user.email
            joinedAt = session.user.createdAt
            userID = session.user.id

            let existing: Profile? = try await supabase
                .from("profiles")
                .select("id, display_name, birth_month, birth_year, avatar_path")
                .eq("id", value: session.user.id.uuidString)
                .maybeSingle()
                .execute()
                .value

            if let existing {
                profile = existing
                savedName = existing.displayName
                pendingBirthMonth = 0
                pendingBirthYear = 0
                await ProfilePhotoService.cleanupReplacedPhotos(for: existing.id)
                await uploadPendingPhoto(for: existing.id)
                if let path = profile?.avatarPath {
                    avatarImage = try? await ProfilePhotoService.download(path: path)
                }
            } else {
                draftName = savedName
                if (1...12).contains(pendingBirthMonth), pendingBirthYear >= 1900, !savedName.isEmpty {
                    draftMonth = pendingBirthMonth
                    draftYear = pendingBirthYear
                    await saveProfile()
                }
            }
        } catch {
            profileLoadFailed = true
            errorMessage = "Could not load your profile: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    private func saveProfile() async {
        guard let userID, !profileLoadFailed else { return }
        let name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let newProfile = NewProfile(id: userID, displayName: name, birthMonth: draftMonth, birthYear: draftYear)
            let saved: Profile = try await supabase
                .from("profiles")
                .insert(newProfile)
                .select("id, display_name, birth_month, birth_year, avatar_path")
                .single()
                .execute()
                .value
            profile = saved
            savedName = saved.displayName
            pendingBirthMonth = 0
            pendingBirthYear = 0
            errorMessage = nil
            await uploadPendingPhoto(for: saved.id)
        } catch {
            errorMessage = "Could not save your profile: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func uploadPendingPhoto(for userID: UUID) async {
        do {
            try await savePendingPhoto(for: userID)
        } catch {
            errorMessage = "Your profile photo couldn't be saved. It will retry next time."
        }
    }

    @MainActor
    private func savePendingPhoto(for userID: UUID) async throws {
        guard let path = try await ProfilePhotoService.uploadPending(
            for: userID,
            replacing: profile?.avatarPath
        ) else { return }
        avatarImage = try? await ProfilePhotoService.download(path: path)
        if let profile {
            self.profile = Profile(
                id: profile.id,
                displayName: profile.displayName,
                birthMonth: profile.birthMonth,
                birthYear: profile.birthYear,
                avatarPath: path
            )
        }
    }

    private func avatarThumbnail(size: CGFloat) -> some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.electricPurple)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @MainActor
    private func refreshPhoto() async throws {
        guard let userID else { return }
        try await savePendingPhoto(for: userID)
    }

    @MainActor
    private func logOut(showOnboarding: Bool = false) async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        if showOnboarding {
            hasAuthenticatedBefore = false
        }

        PendingProfilePhoto.clear()

        // Supabase clears the local session and emits .signedOut before its
        // server request finishes. The root view handles that event and clears
        // cached onboarding data even if the network request fails.
        try? await supabase.auth.signOut(scope: .local)
    }
}
