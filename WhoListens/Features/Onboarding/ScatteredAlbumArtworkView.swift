import SwiftUI

/// A small, open collage of album covers loaded from Spotify's public oEmbed API.
struct ScatteredAlbumArtworkView: View {
    @ObservedObject private var artworkStore = SpotifyArtworkStore.shared

    private struct Cover {
        let index: Int
        let title: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let rotation: Double
    }

    private let covers: [Cover] = [
        Cover(index: 0, title: "After Hours", x: 0.16, y: 0.14, size: 94, rotation: -9),
        Cover(index: 2, title: "HIT ME HARD AND SOFT", x: 0.50, y: 0.09, size: 96, rotation: 6),
        Cover(index: 1, title: "GNX", x: 0.84, y: 0.16, size: 90, rotation: 9),
        Cover(index: 3, title: "Starboy", x: 0.18, y: 0.45, size: 94, rotation: 5),
        Cover(index: 5, title: "SOS", x: 0.50, y: 0.39, size: 96, rotation: -5),
        Cover(index: 6, title: "DAMN.", x: 0.83, y: 0.47, size: 92, rotation: -8),
        Cover(index: 7, title: "Thriller", x: 0.34, y: 0.76, size: 92, rotation: -6),
        Cover(index: 4, title: "Global Warming", x: 0.72, y: 0.77, size: 92, rotation: 7),
    ]

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let height = max(0, geometry.size.height)
            let scale = min(width / 350, height / 480, 1.15)

            ZStack {
                ForEach(covers, id: \.index) { cover in
                    coverArtwork(cover, size: cover.size * scale)
                        .rotationEffect(.degrees(cover.rotation))
                        .position(x: width * cover.x, y: height * cover.y)
                }
            }
        }
        .allowsHitTesting(false)
        .task { await artworkStore.preload() }
    }

    private func coverArtwork(_ cover: Cover, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.17)
                .fill(.white.opacity(0.12))

            if artworkStore.images.indices.contains(cover.index),
               let image = artworkStore.images[cover.index] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3, weight: .light))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.17))
        .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
        .accessibilityLabel("\(cover.title) album cover")
    }
}
