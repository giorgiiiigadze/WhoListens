import Foundation
import Supabase

struct GameRoom: Decodable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let hostID: UUID
    let status: String
    let currentRound: Int

    enum CodingKeys: String, CodingKey {
        case id, code, status
        case hostID = "host_id"
        case currentRound = "current_round"
    }
}

struct RoomPlayer: Decodable, Identifiable {
    let id: UUID
    let userID: UUID
    let score: Int
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, score
        case userID = "user_id"
        case joinedAt = "joined_at"
    }
}

struct GameRound: Decodable, Identifiable {
    let id: UUID
    let roundNumber: Int
    let trackName: String
    let artistName: String
    let albumImageURL: String?
    let status: String
    let isDemo: Bool

    enum CodingKeys: String, CodingKey {
        case id, status
        case roundNumber = "round_number"
        case trackName = "track_name"
        case artistName = "artist_name"
        case albumImageURL = "album_image_url"
        case isDemo = "is_demo"
    }
}

struct GameVote: Decodable, Identifiable {
    let id: UUID
    let voterUserID: UUID
    let guessedUserID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case voterUserID = "voter_user_id"
        case guessedUserID = "guessed_user_id"
    }
}

private struct RoomID: Encodable { let p_room: UUID }
private struct RoomCode: Encodable { let p_code: String }
private struct VoteRequest: Encodable { let p_round: UUID; let p_guess: UUID }
private struct RoundID: Encodable { let p_round: UUID }

enum GameBackend {
    static func create() async throws -> GameRoom {
        try await supabase.rpc("create_game_room").execute().value
    }

    static func join(code: String) async throws -> GameRoom {
        try await supabase.rpc("join_game_room", params: RoomCode(p_code: code)).execute().value
    }

    static func leave(_ id: UUID) async throws {
        try await supabase.rpc("leave_game_room", params: RoomID(p_room: id)).execute()
    }

    static func start(_ id: UUID) async throws {
        try await supabase.rpc("start_game_room", params: RoomID(p_room: id)).execute()
    }

    static func vote(round: UUID, guess: UUID) async throws {
        try await supabase.rpc("cast_game_vote", params: VoteRequest(p_round: round, p_guess: guess)).execute()
    }

    static func advance(_ id: UUID) async throws {
        try await supabase.rpc("advance_game_room", params: RoomID(p_room: id)).execute()
    }

    static func playAgain(_ id: UUID) async throws {
        try await supabase.rpc("play_game_again", params: RoomID(p_room: id)).execute()
    }
}

@MainActor
final class GameSession: ObservableObject {
    @Published private(set) var room: GameRoom
    @Published private(set) var players: [RoomPlayer] = []
    @Published private(set) var round: GameRound?
    @Published private(set) var votes: [GameVote] = []
    @Published private(set) var voteCount = 0
    @Published private(set) var revealedOwnerID: UUID?
    @Published var error: String?
    @Published var busy = false

    private var channel: RealtimeChannelV2?
    private var listeners: [Task<Void, Never>] = []
    let userID: UUID

    init(room: GameRoom, userID: UUID) {
        self.room = room
        self.userID = userID
    }

    var isHost: Bool { room.hostID == userID }
    var hasVoted: Bool { votes.contains { $0.voterUserID == userID } }

    func connect() async {
        do {
            let channel = supabase.channel("game-room-\(room.id.uuidString)")
            self.channel = channel
            let roomChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms", filter: .eq("id", value: room.id))
            let playerChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "room_players", filter: .eq("room_id", value: room.id))
            let roundChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "game_rounds", filter: .eq("room_id", value: room.id))
            try await channel.subscribeWithError()
            await refresh()
            listeners = [
                Task { for await _ in roomChanges { await self.refresh() } },
                Task { for await _ in playerChanges { await self.refresh() } },
                Task { for await _ in roundChanges { await self.refresh() } }
            ]
        } catch {
            self.error = "Could not connect to live room updates: \(error.localizedDescription)"
            await disconnect()
        }
    }

    func disconnect() async {
        listeners.forEach { $0.cancel() }
        listeners.removeAll()
        if let channel { await supabase.removeChannel(channel) }
        channel = nil
    }

    func refresh() async {
        do {
            let latest: GameRoom = try await supabase.from("rooms")
                .select().eq("id", value: room.id).single().execute().value
            let members: [RoomPlayer] = try await supabase.from("room_players")
                .select().eq("room_id", value: room.id)
                .order("joined_at").execute().value
            room = latest
            players = members
            if latest.status == "playing" {
                let current: GameRound? = try await supabase.from("game_rounds")
                    .select().eq("room_id", value: room.id)
                    .eq("round_number", value: latest.currentRound)
                    .limit(1).single().execute().value
                round = current
                if let current {
                    votes = try await supabase.from("votes").select()
                        .eq("round_id", value: current.id).execute().value
                    voteCount = try await supabase.rpc("game_vote_count", params: RoundID(p_round: current.id)).execute().value
                    revealedOwnerID = current.status == "revealed"
                        ? try await supabase.rpc("revealed_round_owner", params: RoundID(p_round: current.id)).execute().value
                        : nil
                }
            } else {
                round = nil
                votes = []
                voteCount = 0
                revealedOwnerID = nil
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await action()
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
