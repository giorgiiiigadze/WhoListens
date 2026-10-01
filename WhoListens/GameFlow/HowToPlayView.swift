import SwiftUI

enum GameMode {
    case create
    case join
}

struct HowToPlayView: View {
    let mode: GameMode
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false
    @State private var showPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Spacer()

            Text("How to play")
                .font(AppTypography.title)
                .padding(.bottom, AppSpacing.small)

            instruction(number: "1", title: "Get your friends in", detail: "Create a room or join one with a code.")
            instruction(number: "2", title: "Take your turn", detail: "Follow the prompt and make your pick.")
            instruction(number: "3", title: "Reveal together", detail: "See what everyone chose and keep the round going.")

            Spacer()

            Button {
                hasSeenHowToPlay = true
                showPreview = true
            } label: {
                Text("Got it")
                    .font(AppTypography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.medium)
            }
            .buttonStyle(PrimaryActionStyle())
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showPreview) {
            GamePreviewView(mode: mode)
        }
    }

    private func instruction(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text(number)
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppColors.electricPurple, in: Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
