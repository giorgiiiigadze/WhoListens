import SwiftUI

struct GamePreviewView: View {
    let mode: GameMode

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: mode == .create ? "person.3.sequence.fill" : "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.electricPurple)
                .padding(.bottom, AppSpacing.small)

            Text(mode == .create ? "Game setup" : "Joining a game")
                .font(AppTypography.title)

            Text("This is a preview of the flow. Live game rooms are coming next.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
