import SwiftUI

struct DisplayNameView: View {
    var onBack: (() -> Void)? = nil
    var onFinished: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("displayName") private var savedName = ""
    @State private var name = ""
    @State private var showPhoto = false
    @FocusState private var nameIsFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            if showPhoto {
                ProfilePhotoView(
                    onBack: {
                        showPhoto = false
                    },
                    onContinue: onFinished
                )
                .transition(OnboardingMotion.transition(reduceMotion: reduceMotion))
            } else {
                nameContent
                .transition(OnboardingMotion.transition(reduceMotion: reduceMotion))
            }
        }
        .animation(OnboardingMotion.animation(reduceMotion: reduceMotion), value: showPhoto)
    }

    private var nameContent: some View {
        VStack(spacing: 0) {
            Text("What should friends call you")
                .font(AppTypography.title)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.large)

            Spacer()

            HStack(spacing: AppSpacing.xSmall) {
                Text("@")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .accessibilityHidden(true)

                TextField("Your name", text: $name)
                    .textContentType(.nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameIsFocused)
                    .foregroundStyle(.black)
                    .tint(.black)
                    .accessibilityLabel("Username")
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 20 {
                            name = String(newValue.prefix(20))
                        }
                    }
                    .onSubmit(continueToAuth)
            }
            .padding(AppSpacing.medium)
            .background(Color(white: 0.985), in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .strokeBorder(.black.opacity(0.10))
            }
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            Spacer()

            Button(action: continueToAuth) {
                Text("Continue")
                    .font(AppTypography.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.medium)
            }
            .buttonStyle(.plain)
            .background(.black, in: Capsule())
            .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .tint(.black)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("Back to age confirmation")
                }
            }
        }
        .onAppear { name = savedName }
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 400))
            guard !Task.isCancelled else { return }
            nameIsFocused = true
        }
    }

    private func continueToAuth() {
        guard !trimmedName.isEmpty else { return }
        savedName = trimmedName
        nameIsFocused = false
        showPhoto = true
    }
}
