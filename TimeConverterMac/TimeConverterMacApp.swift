import AppKit
import SwiftUI

/// The native macOS shell (backlog item 16).
///
/// There is deliberately **no window group**. The Mac product is a menu-bar
/// utility: a `MenuBarExtra` dropdown you click, and a plain panel you summon
/// with ⌃⌥T. Nothing is persistent, nothing sits in the Dock (`LSUIElement` in
/// `project.yml`), and quitting is an explicit menu item because an app with no
/// windows has no ⌘W to close and no Dock icon to right-click.
///
/// This replaces the Mac Catalyst story entirely. Catalyst could reach neither
/// `MenuBarExtra` nor `NSStatusItem` nor Carbon, which is why item 12a had to
/// load a macOS-SDK bundle into the Catalyst process at runtime; a native
/// target makes all three ordinary API and the whole loader retires with it.
/// Everything below the view layer — parsing, the presenter, the debounce — is
/// the shared `TimeConverterCore` package, which is the point of the
/// restructure: two thin shells, one core.
@main
struct TimeConverterMacApp: App {
    /// ⌃⌥T has to be registered at launch, not when the dropdown is first
    /// opened, so it lives on the app delegate's
    /// `applicationDidFinishLaunching` rather than on a view's `onAppear`.
    @NSApplicationDelegateAdaptor(TimeConverterMacDelegate.self)
    private var appDelegate

    var body: some Scene {
        // `.window` rather than the default `.menu`: the dropdown contains a
        // text field, and a menu-style extra cannot host editable controls.
        MenuBarExtra {
            MenuBarConverterView()
        } label: {
            // Template-rendered by default for an SF Symbol, so it tracks the
            // menu bar's light/dark appearance exactly as the retired bundle's
            // status item did.
            Image(systemName: "clock")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Launch-time wiring, and the only reason this app has a delegate at all.
///
/// Keeping the summoner here rather than in a `@State` on the `App` makes the
/// lifetime explicit: registered once at launch, unregistered on the way out.
/// Neither half can fail the launch — a menu-bar utility with no hotkey is
/// still a working menu-bar utility, and that degradation is logged rather
/// than enforced.
final class TimeConverterMacDelegate: NSObject, NSApplicationDelegate {
    private let summoner = PanelSummoner()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            // Belt and braces alongside `LSUIElement`: if the Info.plist key is
            // ever lost, the app would otherwise acquire a Dock icon and a menu
            // bar of its own, which is the one thing the Mac design rules out.
            NSApp.setActivationPolicy(.accessory)
            summoner.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { summoner.stop() }
    }
}
