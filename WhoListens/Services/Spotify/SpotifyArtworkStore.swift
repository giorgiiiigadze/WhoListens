import Foundation
import UIKit

@MainActor
final class SpotifyArtworkStore: ObservableObject {
    static let shared = SpotifyArtworkStore()

    @Published private(set) var images: [UIImage?]
    private var preloadTask: Task<Void, Never>?

    private init() {
        images = Self.loadCachedImages()
    }

    func preload() async {
        if images.allSatisfy({ $0 != nil }) { return }
        if let preloadTask {
            await preloadTask.value
            return
        }

        let task = Task {
            let downloaded = await SpotifyPublicArtworkService().albumArtworkData()
            for (index, data) in downloaded.enumerated() {
                guard images[index] == nil,
                      let data,
                      let image = UIImage(data: data) else { continue }
                images[index] = image
                if let url = Self.cacheURL(for: index) {
                    try? data.write(to: url, options: .atomic)
                }
            }
        }
        preloadTask = task
        await task.value
        preloadTask = nil
    }

    private static func loadCachedImages() -> [UIImage?] {
        SpotifyPublicArtworkService.albumIDs.indices.map { index in
            guard let url = cacheURL(for: index),
                  let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    private static func cacheURL(for index: Int) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = caches.appendingPathComponent("SpotifyArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(SpotifyPublicArtworkService.albumIDs[index]).image")
    }
}
