import SwiftUI

struct SpotifyCachedArtwork: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var loadedImage: UIImage?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let image = SpotifyProfilePreload.shared.image(for: url)
                ?? (loadedURL == url ? loadedImage : nil) {
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
            loadedURL = nil
            guard let url else { return }
            let image = await SpotifyProfilePreload.shared.loadArtwork(at: url)
            guard url == self.url else { return }
            loadedImage = image
            loadedURL = url
        }
    }
}
