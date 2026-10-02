import SwiftUI

struct JoinGameView: View {
    @AppStorage("lastRoomCode") private var lastRoomCode = ""
    @State private var roomCode = ""
    @State private var joinedRoom: GameRoom?
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var codeIsFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 50))
                .foregroundStyle(AppGradients.brand)
            Text("JOIN A ROOM")
                .font(AppTypography.title)
            Text("Enter the four character code your friend shared.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("ROOM CODE", text: $roomCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($codeIsFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(8)
                .padding(20)
                .background(AppColors.electricPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                .onChange(of: roomCode) { _, value in
                    roomCode = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(4))
                }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                codeIsFocused = false
                Task { await join() }
            } label: {
                Group {
                    if isJoining { ProgressView().tint(.white) }
                    else { Text("Join Room") }
                }
                .font(AppTypography.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(roomCode.count != 4 || isJoining)
        }
        .padding(24)
        .background(AppColors.background.ignoresSafeArea())
        .navigationDestination(item: $joinedRoom) { room in RoomSessionView(room: room) }
    }

    private func join() async {
        isJoining = true
        defer { isJoining = false }
        do {
            joinedRoom = try await GameBackend.join(code: roomCode)
            lastRoomCode = joinedRoom?.code ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
