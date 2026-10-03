import PhotosUI
import SwiftUI

struct ProfilePhotoView: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Add a profile photo")
                .font(AppTypography.title)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.large)

            Text("Help friends find you.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.top, AppSpacing.small)

            Spacer()

            VStack(spacing: AppSpacing.large) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))

                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 196, height: 196)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 78, weight: .ultraLight))
                            .foregroundStyle(Color.white.opacity(0.28))
                    }
                }
                .frame(width: 196, height: 196)
                .overlay { Circle().strokeBorder(Color.black.opacity(0.08)) }
                .accessibilityLabel(photoData == nil ? "No profile photo selected" : "Selected profile photo")

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: AppSpacing.small) {
                        if isLoadingPhoto {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "photo")
                        }
                        Text(photoData == nil ? "Choose photo" : "Change photo")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.medium)
                    .background(.white, in: Capsule())
                    .overlay { Capsule().strokeBorder(Color.black.opacity(0.12)) }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPhoto)

                if photoData != nil {
                    Button("Remove photo") {
                        PendingProfilePhoto.clear()
                        photoData = nil
                        selectedItem = nil
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                if let photoError {
                    Text(photoError)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text(photoData == nil ? "Skip for now" : "Continue")
                    .font(AppTypography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.medium)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(isLoadingPhoto)
        }
        .foregroundStyle(AppColors.text)
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Back to display name")
            }
        }
        .onAppear { photoData = PendingProfilePhoto.load() }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(from: item) }
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let jpeg = PendingProfilePhoto.preparedJPEG(from: data) else {
                photoError = "This photo couldn't be used. Please choose another."
                return
            }
            try PendingProfilePhoto.save(jpeg)
            photoData = jpeg
            photoError = nil
        } catch {
            photoError = "This photo couldn't be loaded. Please try again."
        }
    }
}
