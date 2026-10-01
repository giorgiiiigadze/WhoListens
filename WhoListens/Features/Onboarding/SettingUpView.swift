import SwiftUI

struct SettingUpView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            SpotifyCollageView()
                .frame(height: 330)
                .accessibilityHidden(true)

            Spacer()

            VStack(spacing: AppSpacing.small) {
                Text("Setting up everything")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.text)

                Text("Getting things ready for you…")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}
