import SwiftUI

struct PlayTabView: View {
    @AppStorage("lastRoomCode") private var lastRoomCode = ""
    @State private var showJoinGame = false
    @State private var activeRoom: GameRoom?
    @State private var isCreatingRoom = false
    @State private var isResumingRoom = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Play")
                        .font(AppTypography.display)
                    Text("Good music makes a better game night.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.64))
                }

                createCard

                Button { showJoinGame = true } label: {
                    HStack(spacing: 17) {
                        Image(systemName: "number.square.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.warmOrange)
                            .frame(width: 46)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Join a room")
                                .font(.system(size: 19, weight: .bold))
                            Text("Have a code from a friend? Jump in.")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(20)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 25))
                }
                .buttonStyle(.plain)

                if !lastRoomCode.isEmpty {
                    Button { Task { await resumeRoom() } } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(Color(red: 0.28, green: 0.82, blue: 0.66))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Resume room \(lastRoomCode)")
                                    .font(.system(size: 17, weight: .bold))
                                Text("Return to your last game")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer(minLength: 0)
                            if isResumingRoom { ProgressView().tint(.white) }
                        }
                        .padding(19)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 25))
                    }
                    .buttonStyle(.plain)
                    .disabled(isResumingRoom)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("HOW IT WORKS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.55))
                    step("1", "Create or join a room")
                    step("2", "Pick your music")
                    step("3", "Find out who knows you best")
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 25))
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .background(Color(red: 18 / 255, green: 18 / 255, blue: 23 / 255).ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showJoinGame) { JoinGameView() }
        .navigationDestination(item: $activeRoom) { room in
            RoomSessionView(room: room)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 45))
                .foregroundStyle(.white.opacity(0.9))

            Text("Start something good.")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
            Text("Open a room, invite your friends, and let the music do the talking.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.8))

            Button { Task { await createRoom() } } label: {
                Group {
                    if isCreatingRoom { ProgressView().tint(.black) }
                    else { Text("Create a party") }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isCreatingRoom)
            .padding(.top, 6)
        }
        .padding(25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(
            colors: [Color(red: 0.38, green: 0.18, blue: 0.85), AppColors.hotPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ), in: RoundedRectangle(cornerRadius: 28))
    }

    private func step(_ number: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.16), in: Circle())
            Text(title).font(.system(size: 15, weight: .medium))
        }
    }

    @MainActor
    private func createRoom() async {
        guard !isCreatingRoom else { return }
        isCreatingRoom = true
        defer { isCreatingRoom = false }
        do {
            let room = try await GameBackend.create()
            lastRoomCode = room.code
            activeRoom = room
            errorMessage = nil
        } catch {
            errorMessage = "Could not create a room. Please try again."
        }
    }

    @MainActor
    private func resumeRoom() async {
        guard !isResumingRoom else { return }
        isResumingRoom = true
        defer { isResumingRoom = false }
        do {
            activeRoom = try await GameBackend.join(code: lastRoomCode)
            errorMessage = nil
        } catch {
            lastRoomCode = ""
            errorMessage = "That room is no longer available."
        }
    }
}
