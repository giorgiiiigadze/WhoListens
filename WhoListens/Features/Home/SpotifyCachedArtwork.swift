import SwiftUI

struct SpotifyCachedArtwork: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = SpotifyProfilePreload.shared.image(for: url) ?? loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            loadedImage = nil
            guard let url else { return }
            loadedImage = await SpotifyProfilePreload.shared.loadArtwork(at: url)
        }
    }
}
