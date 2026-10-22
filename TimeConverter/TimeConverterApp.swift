import SwiftUI

/// The iOS/iPadOS shell: one window, one `ContentView`, nothing else.
///
/// It used to also start the Mac menu bar here — `MenuBarPresence` loaded a
/// macOS-SDK bundle out of `Contents/PlugIns` when the app was running under
/// Mac Catalyst (backlog item 12a). That is gone: the Mac is its own native
/// target now (`TimeConverterMac`), so this target is iOS-only and has nothing
/// platform-conditional left in it.
@main
struct TimeConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
