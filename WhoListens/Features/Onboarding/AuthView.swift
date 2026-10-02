import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height.isFinite ? max(0, geometry.size.height) : 0

            VStack(alignment: .leading, spacing: 0) {
                ScatteredAlbumArtworkView()
                    .frame(height: min(availableHeight * 0.47, 430))
                    .offset(y: min(availableHeight * 0.14, 120))

                Spacer(minLength: AppSpacing.medium)

                Text("Welcome to Who Listens?")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sign in with Spotify to save your profile and get ready to play with friends.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.small)

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
                .padding(.top, AppSpacing.large)
            }
            .padding(.horizontal, AppSpacing.xLarge)
            .padding(.bottom, AppSpacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
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
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            _ = try await SpotifyPlaylistService.connect()
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                authError = "We couldn't connect to Spotify. Please try again."
            }
        }
    }
}
