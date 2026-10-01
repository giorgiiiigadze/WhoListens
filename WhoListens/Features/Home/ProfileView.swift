import PhotosUI
import SwiftUI

struct ProfileView: View {
    let profile: Profile
    let email: String?
    let joinedAt: Date?
    let age: Int?
    let onPhotoChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var photoError: String?

    init(
        profile: Profile,
        avatarImage: UIImage?,
        email: String?,
        joinedAt: Date?,
        age: Int?,
        onPhotoChanged: @escaping () async -> Void
    ) {
        self.profile = profile
        self.email = email
        self.joinedAt = joinedAt
        self.age = age
        self.onPhotoChanged = onPhotoChanged
        _displayedImage = State(initialValue: avatarImage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                VStack(spacing: 16) {
                    identityCard
                    factsCard
                    emptyCard(
                        title: "YOUR GUESSERS",
                        subtitle: "The ones who always get you right",
                        symbol: "person.2.wave.2.fill",
                        message: "Play with friends to see who knows your music best."
                    )
                    emptyCard(
                        title: "YOUR HITS",
                        subtitle: "The songs everyone guesses right",
                        symbol: "music.note.list",
                        message: "Your most recognized songs will appear here after you play."
                    )
                    musicCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .coordinateSpace(name: "profileScroll")
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel("Close profile")
            }
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if isUpdatingPhoto {
                        ProgressView()
                    } else {
                        Image(systemName: "pencil")
                    }
                }
                .disabled(isUpdatingPhoto)
                .accessibilityLabel("Change profile photo")
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await updatePhoto(from: item) }
        }
        .alert("Photo couldn't be updated", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "Please try again.")
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
                } else {
                    LinearGradient(
                        colors: [AppColors.electricPurple, Color(red: 0.09, green: 0.08, blue: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 180, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.38), location: 0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.3), location: 0.62),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(profile.displayName.uppercased())
                        .font(AppTypography.display)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 8)
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
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height + pullDistance)
            .offset(y: -pullDistance)
        }
        .frame(height: 460)
    }

    private var identityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("FRIENDS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                Text("Your friends will appear here")
                    .font(.system(size: 15, weight: .medium))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.22)))
    }

    private var factsCard: some View {
        HStack(alignment: .top, spacing: 8) {
            fact(symbol: "calendar", title: "JOINED", value: joinedAt?.formatted(.dateTime.month(.abbreviated).year()) ?? "—")
            fact(symbol: "person.fill", title: "AGE", value: age.map(String.init) ?? "—")
            fact(symbol: "gamecontroller.fill", title: "GAMES", value: "Play one")
        }
        .padding(.vertical, 25)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
    }

    private func fact(symbol: String, title: String, value: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 25))
                .frame(height: 32)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyCard(title: String, subtitle: String, symbol: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(AppTypography.title)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 22)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR MUSIC")
                .font(AppTypography.title)
            Text("Spotify is connected. When playlists and listening history are available, you'll find them here.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
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
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 28))
    }

    private var cardBackground: Color { Color(white: 0.15) }

    @MainActor
    private func updatePhoto(from item: PhotosPickerItem) async {
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let jpeg = PendingProfilePhoto.preparedJPEG(from: data),
                  let image = UIImage(data: jpeg) else {
                photoError = "Choose a valid image and try again."
                return
            }
            try PendingProfilePhoto.save(jpeg)
            await onPhotoChanged()
            displayedImage = image
        } catch {
            photoError = error.localizedDescription
        }
    }
}


