import SwiftUI

@main
struct WhoListensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    SpotifyAppAuthenticator.shared.handleCallback(url)
                }
        }
    }
}
