import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var onBack: (() -> Void)? = nil
    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppSpacing.large)

            SpotifyCollageView()
                .frame(height: 330)
                .accessibilityHidden(true)

            Spacer(minLength: AppSpacing.large)

            Button {
                Task { await signInWithSpotify() }
            } label: {
                HStack(spacing: AppSpacing.small) {
                    Image("SpotifyMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text(isAuthenticating ? "Connecting to Spotify…" : "Continue with Spotify")
                        .font(.system(size: 17, weight: .semibold))
                    if isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .foregroundStyle(.white)
                .background(.black, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticating)

            TermsDisclaimer(color: .secondary)
                .padding(.top, AppSpacing.large)
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
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
                    .accessibilityLabel("Back to display name")
                }
            }
        }
        .alert("Spotify sign-in failed", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authError ?? "Please try again.")
        }
    }

    @MainActor
    private func signInWithSpotify() async {
        guard !isAuthenticating else { return }
        guard let redirectURL = URL(string: "com.giorgigiorgadze.wholistens://auth-callback") else {
            authError = "The Spotify callback URL is invalid."
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .spotify,
                redirectTo: redirectURL
            )
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                authError = error.localizedDescription
            }
        }
    }
}
