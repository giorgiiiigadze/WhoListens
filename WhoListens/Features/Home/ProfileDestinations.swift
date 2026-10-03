import PhotosUI
import SwiftUI

struct AddFriendsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.plus").font(.system(size: 44, weight: .light))
            Text("Add friends").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Finding and adding friends is coming soon.").foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(28)
        .background(AppColors.background.ignoresSafeArea()).foregroundStyle(.white)
        .navigationTitle("Friends").navigationBarTitleDisplayMode(.inline)
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
    let avatarImage: UIImage?
    let onProfileChanged: () async -> Void

    private let page = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
    private let card = Color(white: 0.17)
    @State private var isRefreshingSpotify = false
    @State private var spotifyMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NavigationLink {
                    EditProfileView(profile: profile, avatarImage: avatarImage, selectedPhoto: $selectedPhoto, isUpdatingPhoto: isUpdatingPhoto, onProfileChanged: onProfileChanged)
                } label: {
                    HStack(spacing: 14) {
                        avatar(size: 58)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName).font(.system(size: 19, weight: .semibold))
                            Text(email ?? "Edit your profile").font(.system(size: 14)).foregroundStyle(.white.opacity(0.56))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.38))
                    }.padding(16).background(card, in: RoundedRectangle(cornerRadius: 24))
                }.buttonStyle(.plain)

                settingsGroup("MUSIC") {
                    informationRow("Spotify", detail: "Connected to your music", symbol: "music.note")
                    divider
                    Button {
                        Task { await refreshSpotifyAccess() }
                    } label: {
                        settingsActionRow(
                            isRefreshingSpotify ? "Connecting to Spotify…" : "Refresh Spotify access",
                            symbol: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingSpotify)
                }
                settingsGroup("ACCOUNT") {
                    if let email, !email.isEmpty {
                        informationRow("Email", detail: email, symbol: "envelope")
                        divider
                    }
                    if let age {
                        informationRow("Age", detail: String(age), symbol: "person")
                        if joinedAt != nil { divider }
                    }
                    if let joinedAt {
                        informationRow("Joined", detail: joinedAt.formatted(.dateTime.month(.abbreviated).year()), symbol: "calendar")
                    }
                }
                settingsGroup("ABOUT") {
                    informationRow("WhoListens", detail: appVersion, symbol: "info.circle")
                }
                if let onLogOut {
                    Button("Log out", role: .destructive, action: onLogOut).font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 56).background(card, in: Capsule())
                }
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 36)
        }
        .background(page.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .alert("Spotify", isPresented: Binding(
            get: { spotifyMessage != nil },
            set: { if !$0 { spotifyMessage = nil } }
        )) {
            Button("OK", role: .cancel) { spotifyMessage = nil }
        } message: {
            Text(spotifyMessage ?? "")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version)"
    }

    @MainActor private func refreshSpotifyAccess() async {
        isRefreshingSpotify = true
        defer { isRefreshingSpotify = false }
        do {
            _ = try await SpotifyAppAuthenticator.shared.connect()
            spotifyMessage = "Spotify access is up to date."
        } catch {
            spotifyMessage = "Couldn’t refresh Spotify access. Please try again."
        }
    }

    private var divider: some View { Divider().overlay(.white.opacity(0.10)).padding(.leading, 52) }
    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
            VStack(spacing: 0, content: content).background(card, in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private func informationRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium)).frame(width: 24)
            Text(title).font(.system(size: 17, weight: .medium)); Spacer(minLength: 8)
            Text(detail).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
        }.padding(.horizontal, 17).frame(minHeight: 62)
    }
    private func settingsActionRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium)).frame(width: 24)
            Text(title).font(.system(size: 17, weight: .medium))
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }.padding(.horizontal, 17).frame(minHeight: 62)
    }
    @ViewBuilder private func avatar(size: CGFloat) -> some View {
        Group {
            if let avatarImage { Image(uiImage: avatarImage).resizable().scaledToFill() }
            else { Image(systemName: "person.fill").font(.system(size: size * 0.4)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.12)) }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

private struct EditProfileView: View {
    let profile: Profile
    let avatarImage: UIImage?
    @Binding var selectedPhoto: PhotosPickerItem?
    let isUpdatingPhoto: Bool
    let onProfileChanged: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var school = ""
    @State private var work = ""
    @State private var link = ""
    @State private var sign = ""
    @State private var interests = ""
    @State private var isSaving = false
    @State private var saveError: String?
    private let page = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        avatar.frame(width: 154, height: 154).clipShape(Circle())
                        Image(systemName: isUpdatingPhoto ? "hourglass" : "camera.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 44, height: 44).background(.white, in: Circle()).overlay(Circle().stroke(page, lineWidth: 4))
                    }
                }.disabled(isUpdatingPhoto).padding(.top, 24)
                VStack(spacing: 0) {
                    field("Name", text: $name); field("Username", text: $username)
                    field("Bio", text: $bio, placeholder: "Add your bio"); field("Location", text: $location, placeholder: "Add a location")
                    field("Education", text: $school, placeholder: "Add your school"); field("Work", text: $work, placeholder: "Add your work")
                    field("Link", text: $link, placeholder: "Add a link")
                    field("Astrological\nSign", text: $sign, placeholder: "Add your sign", height: 68)
                    field("Interests", text: $interests, placeholder: "Add interests", showsAccentDot: true, isLast: true)
                }
                if let saveError { Text(saveError).font(.footnote).foregroundStyle(.red) }
            }.padding(.bottom, 32)
        }
        .background(page.ignoresSafeArea()).foregroundStyle(.white)
        .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(isSaving ? "Saving…" : "Done") { Task { await save() } }.disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        .onAppear { name = profile.displayName; username = profile.displayName.lowercased().replacingOccurrences(of: " ", with: "_") }
    }
    @ViewBuilder private var avatar: some View {
        if let avatarImage { Image(uiImage: avatarImage).resizable().scaledToFill() }
        else { Image(systemName: "person.fill").font(.system(size: 58)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.12)) }
    }
    private func field(
        _ title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        height: CGFloat = 56,
        showsAccentDot: Bool = false,
        isLast: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 7) {
                    if showsAccentDot {
                        Circle().fill(.white.opacity(0.75))
                            .frame(width: 5, height: 5)
                    }
                    Text(title).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 128, alignment: .leading)
                TextField(placeholder ?? title, text: text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .tint(.white)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: height)
            if !isLast { Divider().overlay(.white.opacity(0.18)) }
        }
    }
    @MainActor private func save() async {
        isSaving = true; saveError = nil; defer { isSaving = false }
        do {
            try await supabase.from("profiles").update(["display_name": name.trimmingCharacters(in: .whitespacesAndNewlines)]).eq("id", value: profile.id.uuidString).execute()
            await onProfileChanged(); dismiss()
        } catch { saveError = "Couldn’t save your profile. Please try again." }
    }
}
