import Foundation
import UIKit

/// The app's side of the menu bar (backlog item 12a): load the bundle, hand it
/// a way back in, tear it down on quit.
///
/// Mac-only and optional-by-design. On iOS every entry point here is a no-op;
/// on Mac Catalyst a failed load is logged and ignored, because a missing menu
/// bar must never cost the user their app. The window-raising half lives in the
/// bundle, where AppKit is legal; this side only decides what the *app* does
/// when summoned, which is the same thing a launcher does minus the reset.
@MainActor
enum MenuBarPresence {
    /// Held for the process's lifetime: releasing it would drop the status item
    /// and the hotkey registration with it.
    private static var host: MenuBarHosting?
    private static var terminationObserver: NSObjectProtocol?

    /// Whether a menu bar is currently up. False on iOS, false under test, and
    /// false whenever the bundle could not be loaded.
    static var isActive: Bool { host != nil }

    /// True while the app is running as a test host.
    ///
    /// `scripts/test.sh --platform mac` launches this very app to host the test
    /// bundle. Putting a status item in the menu bar and grabbing a global
    /// hotkey for the duration of a unit-test run would be a side effect no
    /// test asked for, so the test host stays headless. Both signals are
    /// checked because neither is guaranteed alone: a Swift Testing bundle need
    /// not reference `XCTestCase`, and the environment variable is set by the
    /// `xcodebuild test` harness rather than by the test framework.
    nonisolated static var isRunningUnderTest: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Called once, from `TimeConverterApp.init()`.
    static func startIfAvailable() {
        #if targetEnvironment(macCatalyst)
        guard !isRunningUnderTest else { return }
        guard host == nil else { return }

        let result = MenuBarPlugInLoader.loadHost(at: MenuBarPlugInLoader.expectedBundleURL())
        guard let loadedHost = result.host else {
            // The one line the QA script greps for on the failure path, and the
            // whole of the degradation story: no menu bar, same app.
            MenuBarPlugIn.logger.notice(
                "menu bar unavailable: \(result.diagnostic, privacy: .public) — app continues without it"
            )
            return
        }
        host = loadedHost

        // `onSummon` arrives on the main thread from the bundle, but hopping
        // through a main-actor `Task` rather than asserting it keeps a wrong
        // assumption in the bundle from turning into a crash here.
        let summary = loadedHost.start { Task { @MainActor in summon() } }
        MenuBarPlugIn.logger.notice(
            "menu bar ready: \(result.diagnostic, privacy: .public) — \(summary, privacy: .public)"
        )

        terminationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { stop() } }
        #endif
    }

    /// Clicking the status item, or pressing ⌃⌥T.
    ///
    /// Routed through the same mailbox as the App Shortcut and the Control
    /// Center control, so arriving from the menu bar focuses the field by the
    /// one tested rule rather than by a second copy of it — but as
    /// `.summonWithoutReset`, because a window the user asked to see again is
    /// not a request to throw away what they had typed in it.
    static func summon() {
        LaunchRequestInbox.shared.post(.summonWithoutReset)
    }

    /// Idempotent, and belt-and-braces: the hotkey registration is per-process
    /// WindowServer state that the system reclaims however the process dies, so
    /// this exists for tidiness on an orderly quit, not for correctness.
    static func stop() {
        host?.stop()
        host = nil
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
    }
}
