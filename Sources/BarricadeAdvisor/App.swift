import SwiftUI

@main
struct BarricadeAdvisorApp: App {
    var body: some Scene {
        WindowGroup("Barricade Advisor") {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
