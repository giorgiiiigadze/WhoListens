import SwiftUI

struct ContentView: View {
    private enum SessionState {
        case loading
        case signedIn
        case signedOut
    }

    @State private var sessionState: SessionState = .loading
    @State private var artworkReady = false
    @State private var hasStarted = false
    @State private var showingOnboardingPreview = false
    @State private var previewHasStarted = false
    @AppStorage("hasAuthenticatedBefore") private var hasAuthenticatedBefore = false
    @AppStorage("displayName") private var savedName = ""
    @AppStorage("pendingBirthMonth") private var pendingBirthMonth = 0
    @AppStorage("pendingBirthYear") private var pendingBirthYear = 0

    var body: some View {
        Group {
            switch sessionState {
            case .loading:
                AppGradients.welcome
                    .ignoresSafeArea()
                    .overlay { ProgressView().tint(.white) }
            case .signedIn:
                NavigationStack {
                    HomeView(onShowOnboarding: {
                        previewHasStarted = false
                        showingOnboardingPreview = true
                    })
                }
            case .signedOut:
                if artworkReady {
                    if hasAuthenticatedBefore {
                        NavigationStack {
                            AuthView()
                        }
                    } else {
                        NavigationStack {
                            welcomePage { hasStarted = true }
                                .navigationDestination(isPresented: $hasStarted) {
                                    AgeConfirmationView()
                                }
                        }
                    }
                } else {
                    AppGradients.welcome
                        .ignoresSafeArea()
                        .overlay { ProgressView().tint(.white) }
                }
            }
        }
        .fullScreenCover(isPresented: $showingOnboardingPreview) {
            NavigationStack {
                welcomePage { previewHasStarted = true }
                    .navigationDestination(isPresented: $previewHasStarted) {
                        AgeConfirmationView(isPreview: true)
                    }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    showingOnboardingPreview = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(.black.opacity(0.1)) }
                }
                .accessibilityLabel("Close onboarding preview")
                .padding(.top, AppSpacing.small)
                .padding(.trailing, AppSpacing.xLarge)
            }
        }
        .task {
            await SpotifyArtworkStore.shared.preload()
            artworkReady = true
        }
        .task {
            for await (event, session) in supabase.auth.authStateChanges {
                if event == .signedOut || event == .userDeleted {
                    savedName = ""
                    pendingBirthMonth = 0
                    pendingBirthYear = 0
                    hasStarted = false
                    sessionState = .signedOut
                } else if let session, !session.isExpired {
                    hasAuthenticatedBefore = true
                    sessionState = .signedIn
                } else if event == .initialSession {
                    // A stored session may need a refresh before it can grant access.
                    if let refreshed = try? await supabase.auth.session, !refreshed.isExpired {
                        hasAuthenticatedBefore = true
                        sessionState = .signedIn
                    } else {
                        sessionState = .signedOut
                    }
                } else {
                    sessionState = .signedOut
                }
            }
        }
    }

    private func welcomePage(start: @escaping () -> Void) -> some View {
        GeometryReader { geometry in
            ZStack {
                AppGradients.welcome
                    .ignoresSafeArea()

                welcomeTitle
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.48)

                VStack(spacing: AppSpacing.large) {
                    Button(action: start) {
                        Text("Get Started!")
                            .font(AppTypography.body)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.medium)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
                    }
                    .buttonStyle(.plain)

                    TermsDisclaimer(color: .white)
                }
                .padding(.horizontal, AppSpacing.xLarge)
                .padding(.bottom, AppSpacing.xLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var welcomeTitle: some View {
        Text("Who Listens?")
            .font(AppTypography.display)
            .foregroundStyle(AppColors.textOnBrand)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.large)
    }

}
