import SwiftUI

struct SettingUpView: View {
    let onComplete: () async throws -> Void
    let onStartOver: () async -> Void
    @State private var showsRecoveryAction = false
    @State private var accountNeedsSignIn = false
    @State private var isStartingOver = false

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
                if showsRecoveryAction {
                    Button(accountNeedsSignIn ? "Sign in again" : "Try again") {
                        Task {
                            if accountNeedsSignIn {
                                isStartingOver = true
                                await onStartOver()
                            } else {
                                await finishSetup()
                            }
                        }
                    }
                        .buttonStyle(PrimaryActionStyle())
                        .disabled(isStartingOver)
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
        showsRecoveryAction = false
        accountNeedsSignIn = false
        do {
            try await onComplete()
        } catch is OnboardingAccountError {
            accountNeedsSignIn = true
            showsRecoveryAction = true
            AppToastCenter.shared.show("Your account no longer exists. Sign in again.", style: .error)
        } catch {
            showsRecoveryAction = true
            AppToastCenter.shared.show("We couldn't finish setup. Please try again.", style: .error)
        }
    }
}
