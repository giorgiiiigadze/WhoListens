import Foundation
import UIKit

/// Optional profile-photo fallback for the signed-in Spotify account.
/// Never starts OAuth: the existing WhoListens connection supplies the token.
@MainActor
enum SpotifyProfileImageService {
    private struct SpotifyProfile: Decodable {
        struct Image: Decodable { let url: URL }
        let images: [Image]
    }

    private static var images: [UUID: UIImage] = [:]
    private static var noImage = Set<UUID>()
    private static var pending: [UUID: Task<UIImage?, Never>] = [:]

    static func image(for userID: UUID) async -> UIImage? {
        if let cached = images[userID] { return cached }
        if noImage.contains(userID) { return nil }
        if let task = pending[userID] { return await task.value }

        let task = Task { await fetchImage(for: userID) }
        pending[userID] = task
        let image = await task.value
        pending[userID] = nil
        if let image { images[userID] = image }
        return image
    }

    static func clear() {
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        images.removeAll()
        noImage.removeAll()
    }

    private static func fetchImage(for userID: UUID) async -> UIImage? {
        guard let session = try? await supabase.auth.session,
              session.user.id == userID,
              let token = try? await SpotifyAccessService.shared.accessToken() else { return nil }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        guard let (profileData, profileResponse) = try? await URLSession.shared.data(for: request),
              (profileResponse as? HTTPURLResponse)?.statusCode == 200,
              let profile = try? JSONDecoder().decode(SpotifyProfile.self, from: profileData) else {
            return nil
        }
        guard let url = profile.images.first?.url else {
            noImage.insert(userID)
            return nil
        }
        guard url.scheme == "https" else { return nil }

        var imageRequest = URLRequest(url: url)
        imageRequest.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: imageRequest),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count <= 5_000_000 else { return nil }
        return UIImage(data: data)
    }
}
