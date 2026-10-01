import SwiftUI

private struct Profile: Decodable {
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
    var onShowOnboarding: () -> Void = {}
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0

    @State private var profile: Profile?
    @State private var email: String?
    @State private var userID: UUID?
    @State private var isLoading = true
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

                Text("Your profile")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)

                if isLoading {
                    ProgressView("Loading profile…")
                } else if let profile {
                    VStack(spacing: 0) {
                        detailRow("Display name", value: profile.displayName)
                        Divider()
                        detailRow("Age", value: age.map(String.init) ?? "Not available")
                        Divider()
                        detailRow("Email", value: email ?? "Not available")
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .background(.white, in: RoundedRectangle(cornerRadius: AppCornerRadius.large))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppCornerRadius.large)
                            .strokeBorder(Color.black.opacity(0.08))
                    }
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
                    onShowOnboarding()
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .background(.white, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .strokeBorder(.black.opacity(0.1))
                }
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
            userID = session.user.id

            let existing: Profile? = try await supabase
                .from("profiles")
                .select("id, display_name, birth_month, birth_year")
                .eq("id", value: session.user.id.uuidString)
                .maybeSingle()
                .execute()
                .value

            if let existing {
                profile = existing
                savedName = existing.displayName
                pendingBirthMonth = 0
                pendingBirthYear = 0
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
                .select("id, display_name, birth_month, birth_year")
                .single()
                .execute()
                .value
            profile = saved
            savedName = saved.displayName
            pendingBirthMonth = 0
            pendingBirthYear = 0
            errorMessage = nil
        } catch {
            errorMessage = "Could not save your profile: \(error.localizedDescription)"
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.medium)
    }

    @MainActor
    private func logOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        // Supabase clears the local session and emits .signedOut before its
        // server request finishes. The root view handles that event and clears
        // cached onboarding data even if the network request fails.
        try? await supabase.auth.signOut(scope: .local)
    }
}
