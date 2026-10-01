import SwiftUI
import UIKit

struct StickerTitle: View {
    let width: CGFloat

    private let title = "WHO\nLISTENS?"

    private var safeWidth: CGFloat {
        width.isFinite ? max(0, width) : 0
    }

    private var fontSize: CGFloat {
        let sampleFont = UIFont(name: "BowlbyOne-Regular", size: 50) ?? .systemFont(ofSize: 50, weight: .black)
        let longestLine = ("LISTENS?" as NSString).size(withAttributes: [.font: sampleFont]).width
        guard longestLine > 0 else { return 1 }
        return max(1, min(52, 50 * max(0, safeWidth - 30) / longestLine))
    }

    var body: some View {
        ZStack {
            titleLayer(strokeColor: .white, strokeWidth: 36)
            titleLayer(strokeColor: .black, strokeWidth: 24)
            titleLayer(strokeColor: nil, strokeWidth: 0)
        }
        .frame(width: safeWidth, height: 170)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Who Listens?")
    }

    private func titleLayer(strokeColor: UIColor?, strokeWidth: CGFloat) -> some View {
        StickerTextLayer(
            text: title,
            fontSize: fontSize,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        )
        .frame(width: safeWidth, height: 170)
    }
}

private struct StickerTextLayer: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let strokeColor: UIColor?
    let strokeWidth: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 2
        label.textAlignment = .center
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let font = UIFont(name: "BowlbyOne-Regular", size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .black)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = -7

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        if let strokeColor {
            attributes[.strokeColor] = strokeColor
            attributes[.strokeWidth] = strokeWidth
        }
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}
