import SwiftUI

struct JoinGameView: View {
    @AppStorage("hasSeenHowToPlay") private var hasSeenHowToPlay = false
    @State private var roomCode = ""
    @State private var showNext = false
    @FocusState private var codeIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Spacer()

            Image(systemName: "number.square")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppColors.electricPurple)
                .padding(.bottom, AppSpacing.small)

            Text("Join a game")
                .font(AppTypography.title)

            Text("Ask your friend for their 6-character room code.")
                .font(.body)
                .foregroundStyle(.secondary)

            TextField("Room code", text: $roomCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($codeIsFocused)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(3)
                .padding(AppSpacing.medium)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                .onChange(of: roomCode) { _, newValue in
                    roomCode = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                }

            Spacer()

            Button {
                codeIsFocused = false
                showNext = true
            } label: {
                Text("Continue")
                    .font(AppTypography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.medium)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(roomCode.count != 6)
        }
        .padding(.horizontal, AppSpacing.xLarge)
        .padding(.bottom, AppSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showNext) {
            if hasSeenHowToPlay {
                GamePreviewView(mode: .join)
            } else {
                HowToPlayView(mode: .join)
            }
        }
    }
}
