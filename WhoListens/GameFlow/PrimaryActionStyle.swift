import SwiftUI

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(isEnabled ? Color.black : Color.black.opacity(0.35), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
