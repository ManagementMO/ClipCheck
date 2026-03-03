import SwiftUI

@main
struct ReactivChallengeKitApp: App {
    @State private var router = ClipRouter()

    var body: some Scene {
        WindowGroup {
            SimulatorShell(router: router)
        }
    }
}
