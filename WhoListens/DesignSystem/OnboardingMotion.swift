import SwiftUI

enum OnboardingMotion {
    static func transition(reduceMotion: Bool, forward _: Bool = true) -> AnyTransition {
        .opacity
    }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.36)
    }
}
