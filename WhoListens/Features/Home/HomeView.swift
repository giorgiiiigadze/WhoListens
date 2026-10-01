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

    @State private var profile: Profile?
    @State private var avatarImage: UIImage?
    @State private var email: String?
    @State private var joinedAt: Date?
    @State private var userID: UUID?
    @State private var isLoading = true
    @State private var isShowingProfile = false
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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Home")
                    .font(AppTypography.display)
                    .padding(.top, AppSpacing.large)

                if isLoading {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let profile {
                    Button { isShowingProfile = true } label: {
                        HStack(spacing: 16) {
                            avatarThumbnail
                            VStack(alignment: .leading, spacing: 5) {
                                Text("YOUR PROFILE")
                                    .font(AppTypography.title)
                                Text(profile.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.headline)
                        }
                        .foregroundStyle(AppColors.text)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(.black.opacity(0.08))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open your profile")
                } else {
                    setupForm
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                #if DEBUG
                Button("Show onboarding") {
                    Task { await logOut(showOnboarding: true) }
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .background(.white, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .strokeBorder(.black.opacity(0.1))
                }
                .disabled(isSigningOut)
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xLarge)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log out") {
                    Task { await logOut() }
                }
                .font(.system(size: 16, weight: .semibold))
                .disabled(isSigningOut)
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
                        onPhotoChanged: { await refreshPhoto() }
                    )
                }
            }
        }
        .task { await loadProfile() }
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
        .background(.white, in: RoundedRectangle(cornerRadius: AppCornerRadius.large))
    }

    @MainActor
    private func loadProfile() async {
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
            errorMessage = "Could not load your profile: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    private func saveProfile() async {
        guard let userID else { return }
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
            if let path = try await ProfilePhotoService.uploadPending(for: userID) {
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
        } catch {
            errorMessage = "Your profile photo couldn't be saved. It will retry next time."
        }
    }

    private var avatarThumbnail: some View {
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
        .frame(width: 58, height: 58)
        .clipShape(Circle())
    }

    @MainActor
    private func refreshPhoto() async {
        guard let userID else { return }
        await uploadPendingPhoto(for: userID)
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
