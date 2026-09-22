import SwiftUI

@main
struct AIComposeCameraApp: App {

    init() {
        SecurityHardener.applyProtections()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
