import SwiftUI

struct ScatteredAlbumArtworkView: View {
    @ObservedObject private var artworkStore = SpotifyArtworkStore.shared

    private struct Cover {
        let index: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let colors: [Color]
    }

    private let covers: [Cover] = [
        Cover(index: 0, x: 0.15, y: 0.27, size: 100, colors: [.cyan, .blue]),
        Cover(index: 1, x: 0.54, y: 0.19, size: 106, colors: [.black, .gray]),
        Cover(index: 2, x: 0.87, y: 0.29, size: 96, colors: [.green, .teal]),
        Cover(index: 3, x: 0.21, y: 0.58, size: 108, colors: [.red, .orange]),
        Cover(index: 4, x: 0.73, y: 0.53, size: 100, colors: [.orange, .pink]),
        Cover(index: 5, x: 0.27, y: 0.84, size: 94, colors: [.blue, .indigo]),
        Cover(index: 6, x: 0.80, y: 0.84, size: 100, colors: [.red, .black])
    ]

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 390, geometry.size.height / 440, 1)

            ZStack {
                ForEach(covers.indices, id: \.self) { index in
                    let cover = covers[index]
                    coverCard(cover, size: cover.size * scale)
                        .position(
                            x: geometry.size.width * cover.x,
                            y: geometry.size.height * cover.y
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func coverCard(_ cover: Cover, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(LinearGradient(
                colors: cover.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay {
                if artworkStore.images.indices.contains(cover.index),
                   let image = artworkStore.images[cover.index] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .strokeBorder(.white, lineWidth: 3 * (size / cover.size))
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 7)
    }
}
