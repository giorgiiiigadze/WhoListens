import SwiftUI

@main
struct WhoListensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    SpotifyAppAuthenticator.shared.handleCallback(url)
                }
        }
    }
}
