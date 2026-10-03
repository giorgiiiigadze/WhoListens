import PhotosUI
import SwiftUI

struct AddFriendsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.8))
            Text("Add friends")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Finding and adding friends is coming soon.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileSettingsView: View {
    let profile: Profile
    let email: String?
    let joinedAt: Date?
    let age: Int?
    @Binding var selectedPhoto: PhotosPickerItem?
    let isUpdatingPhoto: Bool
    let onLogOut: (() -> Void)?

    var body: some View {
        List {
            Section("Profile") {
                LabeledContent("Name", value: profile.displayName)
                if let age { LabeledContent("Age", value: String(age)) }
                if let joinedAt {
                    LabeledContent("Joined", value: joinedAt.formatted(.dateTime.month(.abbreviated).year()))
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Label("Change profile photo", systemImage: "photo")
                        Spacer()
                        if isUpdatingPhoto { ProgressView() }
                    }
                }
                .disabled(isUpdatingPhoto)
            }

            if let email {
                Section("Account") {
                    LabeledContent("Email", value: email)
                }
            }

            if let onLogOut {
                Section {
                    Button("Log out", role: .destructive, action: onLogOut)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
