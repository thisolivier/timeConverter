import SwiftUI

@main
struct TimeConverterApp: App {
    init() {
        // Mac only, and optional by design: on Mac Catalyst this loads the
        // menu-bar bundle out of Contents/PlugIns and brings up a status item
        // plus ⌃⌥T. On iOS, and whenever the bundle is missing or refuses to
        // load, it logs and does nothing else. See TimeConverter/MenuBar.
        MenuBarPresence.startIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
