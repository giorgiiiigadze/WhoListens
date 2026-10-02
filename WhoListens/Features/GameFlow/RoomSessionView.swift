import SwiftUI

struct RoomSessionView: View {
    let room: GameRoom
    @State private var session: GameSession?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let session {
                RoomSessionContent(session: session)
            } else if let loadError {
                ContentUnavailableView("Could not open room", systemImage: "wifi.exclamationmark", description: Text(loadError))
            } else {
                ProgressView("Connecting to room…")
            }
        }
        .task {
            guard session == nil else { return }
            do {
                let userID = try await supabase.auth.session.user.id
                let live = GameSession(room: room, userID: userID)
                session = live
                await live.connect()
            } catch {
                loadError = error.localizedDescription
            }
        }
        .onDisappear { if let session { Task { await session.disconnect() } } }
    }
}

private struct RoomSessionContent: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch session.room.status {
            case "waiting": RoomLobbyView(session: session, dismiss: dismiss.callAsFunction)
            case "playing":
                if let round = session.round {
                    if round.status == "revealed" {
                        RoundRevealView(session: session, round: round)
                    } else {
                        GameView(session: session, round: round)
                    }
                } else {
                    ProgressView("Loading round…")
                }
            case "completed": LeaderboardView(session: session, dismiss: dismiss.callAsFunction)
            default: ContentUnavailableView("Room closed", systemImage: "door.left.hand.closed")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            if let error = session.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
                    .onTapGesture { session.error = nil }
            }
        }
    }
}

struct RoomLobbyView: View {
    @ObservedObject var session: GameSession
    let dismiss: () -> Void
    @AppStorage("lastRoomCode") private var lastRoomCode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Who Listens?").font(AppTypography.display)
                    .foregroundStyle(AppGradients.brand)
                    .padding(.top, 32)
                Text("ROOM CODE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(session.room.code)
                    .font(.system(size: 52, weight: .black, design: .rounded)).tracking(8)
                HStack {
                    Button("Copy") { UIPasteboard.general.string = session.room.code }
                    ShareLink(item: "Join my WhoListens room! Code: \(session.room.code)") {
                        Label("Invite Friends", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)
                Text("PLAYERS · \(session.players.count)")
                    .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                    HStack(spacing: 16) {
                        PlayerAvatar(number: index + 1)
                        Text(playerLabel(player, in: session))
                            .font(.headline)
                        if player.userID == session.room.hostID {
                            Image(systemName: "crown.fill").foregroundStyle(.yellow)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AppColors.electricPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                }
                Spacer(minLength: 32)
                if session.isHost {
                    Button {
                        Task { await session.perform { try await GameBackend.start(session.room.id) } }
                    } label: {
                        Text("Start Game")
                            .font(AppTypography.body).frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(session.players.count < 2 || session.busy)
                    if session.players.count < 2 { Text("Invite at least one friend to play.").foregroundStyle(.secondary) }
                } else {
                    Text("Waiting for host…").font(.headline).foregroundStyle(.secondary)
                }
                Button("Leave Room") {
                    Task {
                        await session.perform { try await GameBackend.leave(session.room.id) }
                        if session.error == nil { lastRoomCode = ""; dismiss() }
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

struct GameView: View {
    @ObservedObject var session: GameSession
    let round: GameRound
    @State private var selected: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("ROOM \(session.room.code) · ROUND \(round.roundNumber)/\(session.players.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(Array(session.players.enumerated()), id: \.element.id) { index, _ in
                        PlayerAvatar(number: index + 1).overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30).fill(AppGradients.brand)
                    if let urlString = round.albumImageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "music.note").font(.system(size: 80)).foregroundStyle(.white) }
                    } else {
                        Image(systemName: "music.note").font(.system(size: 80)).foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: 310).frame(height: 310).clipShape(RoundedRectangle(cornerRadius: 30))
                Text(round.trackName).font(AppTypography.title).multilineTextAlignment(.center)
                Text(round.artistName).foregroundStyle(.secondary)
                if round.isDemo {
                    Text("DEMO ROUND · Spotify tracks are not connected yet")
                        .font(.caption).foregroundStyle(AppColors.electricPurple)
                }
                Text("Who listens to this?").font(.title2.bold()).padding(.top, 8)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                        Button {
                            if !session.hasVoted { selected = player.userID }
                        } label: {
                            VStack(spacing: 8) {
                                PlayerAvatar(number: index + 1)
                                Text(playerLabel(player, in: session)).font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(16)
                            .background(selected == player.userID ? AppColors.electricPurple.opacity(0.25) : AppColors.electricPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected == player.userID ? AppColors.electricPurple : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if session.hasVoted {
                    Text("Waiting for everyone… \(session.voteCount) / \(session.players.count) guessed")
                        .font(.headline).foregroundStyle(.secondary)
                } else {
                    Button {
                        guard let selected else { return }
                        Task { await session.perform { try await GameBackend.vote(round: round.id, guess: selected) } }
                    } label: {
                        Text("LOCK IN").font(AppTypography.body).frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(selected == nil || session.busy)
                }
            }
            .padding(24)
        }
    }
}

struct RoundRevealView: View {
    @ObservedObject var session: GameSession
    let round: GameRound

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)
                Text("IT WAS…").font(AppTypography.display).foregroundStyle(AppGradients.brand)
                if let owner = session.players.first(where: { $0.userID == session.revealedOwnerID }),
                   let index = session.players.firstIndex(where: { $0.id == owner.id }) {
                    PlayerAvatar(number: index + 1).scaleEffect(1.8).padding(30)
                    Text(playerLabel(owner, in: session)).font(AppTypography.title)
                }
                Text(round.trackName).foregroundStyle(.secondary)
                ForEach(session.votes) { vote in
                    HStack {
                        Text(label(vote.voterUserID))
                        Image(systemName: "arrow.right")
                        Text(label(vote.guessedUserID))
                        Spacer()
                        Image(systemName: vote.guessedUserID == session.revealedOwnerID ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(vote.guessedUserID == session.revealedOwnerID ? .green : .red)
                    }
                    .padding().background(AppColors.electricPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
                if session.isHost {
                    Button {
                        Task { await session.perform { try await GameBackend.advance(session.room.id) } }
                    } label: {
                        Text(round.roundNumber == session.players.count ? "See Leaderboard" : "Next Round")
                            .font(AppTypography.body).frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(PrimaryActionStyle()).disabled(session.busy)
                } else { Text("Waiting for host…").foregroundStyle(.secondary) }
            }.padding(24)
        }
    }

    private func label(_ id: UUID) -> String {
        guard let player = session.players.first(where: { $0.userID == id }) else { return "Player" }
        return playerLabel(player, in: session)
    }
}

struct LeaderboardView: View {
    @ObservedObject var session: GameSession
    let dismiss: () -> Void
    @AppStorage("lastRoomCode") private var lastRoomCode = ""

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("WHO KNOWS THEIR FRIENDS BEST?")
                .font(AppTypography.title).multilineTextAlignment(.center)
            ForEach(Array(session.players.sorted { $0.score > $1.score }.enumerated()), id: \.element.id) { index, player in
                HStack {
                    Text(["🥇", "🥈", "🥉"].indices.contains(index) ? ["🥇", "🥈", "🥉"][index] : "\(index + 1).")
                    Text(playerLabel(player, in: session)).font(.headline)
                    Spacer()
                    Text("\(player.score)").font(.title2.bold())
                }
                .padding().background(player.userID == session.userID ? AppColors.electricPurple.opacity(0.2) : AppColors.electricPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer()
            if session.isHost {
                Button {
                    Task { await session.perform { try await GameBackend.playAgain(session.room.id) } }
                } label: { Text("Play Again").font(AppTypography.body).frame(maxWidth: .infinity).padding(18) }
                    .buttonStyle(PrimaryActionStyle()).disabled(session.busy)
            }
            Button("Leave Room") {
                Task {
                    await session.perform { try await GameBackend.leave(session.room.id) }
                    if session.error == nil { lastRoomCode = ""; dismiss() }
                }
            }
        }.padding(24)
    }
}

private struct PlayerAvatar: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.headline).foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(AppGradients.brand, in: Circle())
    }
}

@MainActor private func playerLabel(_ player: RoomPlayer, in session: GameSession) -> String {
    if player.userID == session.userID {
        let name = UserDefaults.standard.string(forKey: "displayName") ?? ""
        return name.isEmpty ? "You" : "\(name) (you)"
    }
    let number = (session.players.firstIndex(where: { $0.id == player.id }) ?? 0) + 1
    return "Player \(number)"
}
