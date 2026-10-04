import Foundation

struct FriendUser: Decodable, Identifiable, Hashable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct FriendConnection: Decodable, Identifiable {
    enum Status: String, Decodable { case pending, accepted }
    enum Direction: String, Decodable { case incoming, outgoing }

    let id: UUID
    let user: FriendUser
    let status: Status
    let direction: Direction
}

enum FriendsService {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Items<T: Decodable>: Decodable { let items: [T] }
    private struct APIError: Decodable { let error: String }

    static func search(_ query: String) async throws -> [FriendUser] {
        try await request(["action": "search", "query": query], as: Items<FriendUser>.self).items
    }

    static func connections() async throws -> [FriendConnection] {
        try await request(["action": "list"], as: Items<FriendConnection>.self).items
    }

    static func send(to userID: UUID) async throws {
        _ = try await request(["action": "send", "user_id": userID.uuidString], as: Result.self)
    }

    static func change(_ action: String, connectionID: UUID) async throws {
        _ = try await request(["action": action, "id": connectionID.uuidString], as: Result.self)
    }

    private struct Result: Decodable { let ok: Bool }

    private static func request<T: Decodable>(_ body: [String: String], as type: T.Type) async throws -> T {
        let session = try await supabase.auth.session
        var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/friends"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw Failure(message: "Could not reach friends right now.")
        }
        guard response.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error)
                ?? "Could not load friends right now."
            throw Failure(message: message)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}
