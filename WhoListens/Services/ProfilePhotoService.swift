import Foundation
import Supabase
import UIKit

@MainActor
enum PendingProfilePhoto {
    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pending-profile-photo.jpg")
    }

    static func load() -> Data? {
        guard let fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    static func save(_ data: Data) throws {
        guard let fileURL else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func preparedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let side: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let square = renderer.image { _ in
            let scale = max(side / image.size.width, side / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(
                x: (side - width) / 2,
                y: (side - height) / 2,
                width: width,
                height: height
            ))
        }

        for quality in [0.8, 0.65, 0.5] {
            if let jpeg = square.jpegData(compressionQuality: quality), jpeg.count <= 1_048_576 {
                return jpeg
            }
        }
        return nil
    }
}

enum ProfilePhotoService {
    private struct AvatarUpdate: Decodable {
        let avatarPath: String

        enum CodingKeys: String, CodingKey {
            case avatarPath = "avatar_path"
        }
    }

    static func download(path: String) async throws -> UIImage? {
        let data = try await supabase.storage.from("profile-photos").download(path: path)
        return UIImage(data: data)
    }

    @MainActor
    static func uploadPending(for userID: UUID) async throws -> String? {
        guard let data = PendingProfilePhoto.load() else { return nil }
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        try await supabase.storage.from("profile-photos").upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg")
        )

        do {
            let updated: AvatarUpdate = try await supabase.from("profiles")
                .update(["avatar_path": path])
                .eq("id", value: userID.uuidString)
                .select("avatar_path")
                .single()
                .execute()
                .value
            guard updated.avatarPath == path else { throw CocoaError(.fileWriteUnknown) }
        } catch {
            _ = try? await supabase.storage.from("profile-photos").remove(paths: [path])
            throw error
        }

        PendingProfilePhoto.clear()
        return path
    }
}
