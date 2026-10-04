import SwiftUI

extension View {
    @ViewBuilder
    func profileGlassCard(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
