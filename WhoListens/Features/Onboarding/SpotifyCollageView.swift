import SwiftUI

struct SpotifyCollageView: View {
    @ObservedObject private var artworkStore = SpotifyArtworkStore.shared

    var body: some View {
        placeholderCollage
    }

    private func artworkImage(at index: Int) -> UIImage? {
        artworkStore.images.indices.contains(index) ? artworkStore.images[index] : nil
    }

    private var placeholderCollage: some View {
        GeometryReader { geometry in
            let width = geometry.size.width.isFinite ? max(0, geometry.size.width) : 0
            let height = geometry.size.height.isFinite ? max(0, geometry.size.height) : 0
            let scale = min(width / 330, 1)
            let centerX = width / 2
            let centerY = height / 2

            ZStack {
                Ellipse()
                    .fill(AppColors.warmOrange.opacity(0.2))
                    .frame(width: 260 * scale, height: 140 * scale)
                    .blur(radius: 38 * scale)
                    .position(x: centerX, y: centerY + 35 * scale)

                coverCard(colors: [.cyan, .blue], size: 88 * scale, artworkImage: artworkImage(at: 0))
                    .blur(radius: 12 * scale)
                    .position(x: centerX + 135 * scale, y: centerY - 78 * scale)

                coverCard(colors: [.black, .gray], size: 85 * scale, artworkImage: artworkImage(at: 1))
                    .blur(radius: 13 * scale)
                    .position(x: centerX + 151 * scale, y: centerY + 72 * scale)

                coverCard(colors: [.green, .teal], size: 86 * scale, artworkImage: artworkImage(at: 2))
                    .position(x: centerX - 104 * scale, y: centerY - 112 * scale)

                coverCard(colors: [.blue, .indigo], size: 60 * scale, artworkImage: artworkImage(at: 3))
                    .position(x: centerX - 71 * scale, y: centerY - 20 * scale)

                coverCard(colors: [.black, Color(white: 0.22)], size: 89 * scale, artworkImage: artworkImage(at: 4))
                    .position(x: centerX - 148 * scale, y: centerY + 8 * scale)

                RoundedRectangle(cornerRadius: 23 * scale)
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.27, blue: 0.09), AppColors.warmOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 108 * scale, height: 108 * scale)
                    .overlay {
                        Text("Who\nListens?")
                            .font(.custom("BowlbyOne-Regular", size: 17 * scale))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 23 * scale)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                    .shadow(color: AppColors.warmOrange.opacity(0.35), radius: 24 * scale, y: 14 * scale)
                    .position(x: centerX, y: centerY)
            }
        }
    }

    private func coverCard(colors: [Color], size: CGFloat, artworkImage: UIImage?) -> some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                if let artworkImage {
                    Image(uiImage: artworkImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }
}
