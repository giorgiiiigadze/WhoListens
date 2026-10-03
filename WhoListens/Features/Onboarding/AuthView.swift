import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var storyIndex = 0
    @State private var storyStartedAt = Date()
    @State private var storyGeneration = 0
    @State private var transitionDirection = 1

    private let storyCount = 3
    private let storyDuration: TimeInterval = 5
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                storyBackground

                VStack(spacing: 0) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                        HStack(spacing: 5) {
                            ForEach(0..<storyCount, id: \.self) { index in
                                GeometryReader { segment in
                                    Capsule()
                                        .fill(.white.opacity(0.35))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(.white)
                                                .frame(width: segment.size.width * progress(for: index, at: timeline.date))
                                        }
                                        .clipShape(Capsule())
                                }
                                .frame(height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.top, 12)
                    .accessibilityLabel("Story \(storyIndex + 1) of \(storyCount)")

                    Text("Who Listens?")
                        .font(AppTypography.display)
                        .foregroundStyle(.white)
                        .padding(.top, 35)

                    ZStack {
                        if storyIndex == 0 {
                            ScatteredAlbumArtworkView()
                                .transition(storyTransition)
                        }
                    }
                    .frame(height: min(geometry.size.height * 0.60, 480))
                    .padding(.top, 48)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: storyIndex)

                    Spacer(minLength: 24)

                    Button { Task { await signInWithSpotify() } } label: {
                        HStack(spacing: AppSpacing.small) {
                            Image("SpotifyMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .colorMultiply(Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255))
                            Text(isAuthenticating ? "Connecting to Spotify…" : "Continue with Spotify")
                                .font(.system(size: 17, weight: .semibold))
                            if isAuthenticating {
                                ProgressView().tint(.black)
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.medium)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthenticating)

                    TermsDisclaimer(color: .white.opacity(0.53))
                        .padding(.top, 18)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, max(14, geometry.safeAreaInsets.bottom == 0 ? 20 : 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                if value.translation.width < -40 { moveStory(by: 1) }
                if value.translation.width > 40 { moveStory(by: -1) }
            })
        }
        .preferredColorScheme(.dark)
        .task(id: storyGeneration) {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(storyDuration))
            guard !Task.isCancelled else { return }
            transitionDirection = 1
            storyIndex = (storyIndex + 1) % storyCount
            storyStartedAt = Date()
            storyGeneration += 1
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

    private var storyBackground: some View {
        AppColors.background.ignoresSafeArea()
    }

    private var storyTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: CGFloat(transitionDirection) * 65).combined(with: .opacity),
            removal: .offset(x: CGFloat(transitionDirection) * -65).combined(with: .opacity)
        )
    }

    private func progress(for index: Int, at date: Date) -> CGFloat {
        if index < storyIndex { return 1 }
        if index > storyIndex { return 0 }
        if reduceMotion { return 1 }
        return CGFloat(min(1, max(0, date.timeIntervalSince(storyStartedAt) / storyDuration)))
    }

    private func moveStory(by offset: Int) {
        transitionDirection = offset
        storyIndex = min(max(storyIndex + offset, 0), storyCount - 1)
        storyStartedAt = Date()
        storyGeneration += 1
    }

    @MainActor
    private func signInWithSpotify() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await SpotifyAppAuthenticator.shared.signIn()
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                authError = "We couldn't connect to Spotify. Please try again."
            }
        }
    }
}
