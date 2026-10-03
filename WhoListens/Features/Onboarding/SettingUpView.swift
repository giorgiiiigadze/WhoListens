import SwiftUI

struct SettingUpView: View {
    let onComplete: () async throws -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: -12) {
                SpotifyCollageView()
                    .frame(height: 330)
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.small) {
                    Text("Setting up everything")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    Text("Getting things ready for you…")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    Button("Try again") { Task { await finishSetup() } }
                        .buttonStyle(PrimaryActionStyle())
                        .padding(.top, 12)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task { await finishSetup() }
    }

    @MainActor
    private func finishSetup() async {
        errorMessage = nil
        do {
            try await onComplete()
        } catch {
            errorMessage = "We couldn't finish setting up your profile. Please try again."
        }
    }
}
