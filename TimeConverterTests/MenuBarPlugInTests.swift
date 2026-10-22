import Foundation
import Testing
@testable import TimeConverter

/// Item 12a — the parts of the menu bar that can be proven without a menu bar.
///
/// The status item, the ⌃⌥T registration and the window raise are macOS-SDK
/// platform glue living in a bundle this test target cannot even load, and they
/// are verified by launching (`scripts/qa-menubar.sh`, plus one manual
/// keypress — see the README's Mac section). What *is* testable headlessly, on
/// both lanes, is the contract that connects the two sides and the app's
/// behaviour when the connection fails — which is the normal case on iOS.
struct MenuBarPlugInTests {
    /// The sharpest trap in the whole design, and the one the compiler cannot
    /// catch: the cast across the bundle boundary resolves by ObjC runtime
    /// name. With a plain `@objc protocol` the two compilations mangle that
    /// name differently, the bundle loads, the principal class resolves, and
    /// the cast fails anyway. If this assertion ever breaks, the menu bar stops
    /// appearing with no other symptom.
    @Test func theHostingProtocolKeepsItsExplicitObjectiveCName() {
        #expect(NSProtocolFromString(MenuBarPlugIn.hostingProtocolName) != nil)
        #expect(NSStringFromProtocol(MenuBarHosting.self) == MenuBarPlugIn.hostingProtocolName)
    }

    /// `NSPrincipalClass` in `project.yml` is a string, matched against the
    /// `@objc(…)` name on the implementation. Nothing checks the two agree at
    /// build time, so the name is pinned here as a constant the loader uses for
    /// its diagnostics too.
    @Test func thePrincipalClassNameIsTheObjectiveCName() {
        #expect(MenuBarPlugIn.principalClassName == "MenuBarController")
        #expect(MenuBarPlugIn.bundleFileName == "TimeConverterMenuBar.bundle")
    }

    @Test func theBundleIsLookedForByNameInsidePlugIns() throws {
        let plugIns = URL(fileURLWithPath: "/Applications/TimeConverter.app/Contents/PlugIns")
        let expected = try #require(MenuBarPlugInLoader.expectedBundleURL(inPlugInsDirectory: plugIns))

        #expect(expected.lastPathComponent == MenuBarPlugIn.bundleFileName)
        #expect(expected.deletingLastPathComponent().path == plugIns.path)
    }

    @Test func anAppWithNoPlugInsDirectoryHasNoMenuBar() {
        let result = MenuBarPlugInLoader.loadHost(at: MenuBarPlugInLoader.expectedBundleURL(inPlugInsDirectory: nil))

        #expect(result.host == nil)
        #expect(!result.diagnostic.isEmpty)
    }

    /// The iOS case, and the "Olivier moved the bundle out of PlugIns" case:
    /// every step of the load is optional, so an absent bundle is a sentence in
    /// the log rather than a failed launch.
    @Test func anAbsentBundleIsReportedRatherThanFatal() {
        let missing = URL(fileURLWithPath: "/nonexistent/TimeConverter.app/Contents/PlugIns")
            .appendingPathComponent(MenuBarPlugIn.bundleFileName)
        let result = MenuBarPlugInLoader.loadHost(at: missing)

        #expect(result.host == nil)
        #expect(result.diagnostic.contains("not present"))
    }

    /// A directory that exists but is not a loadable bundle — a half-copied
    /// build, or one for the wrong architecture. Also survivable.
    @Test func somethingThatIsNotABundleIsReportedRatherThanFatal() throws {
        let impostor = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MenuBarPlugInTests-\(UUID().uuidString)")
            .appendingPathComponent(MenuBarPlugIn.bundleFileName)
        try FileManager.default.createDirectory(at: impostor, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: impostor.deletingLastPathComponent()) }

        let result = MenuBarPlugInLoader.loadHost(at: impostor)

        #expect(result.host == nil)
        #expect(!result.diagnostic.isEmpty)
    }
}

@MainActor
struct MenuBarPresenceTests {
    /// Running the app as a test host must not put a status item in Olivier's
    /// menu bar or take a global hotkey for the length of a test run. This is
    /// the assertion that proves the guard works, by being true *because* it is
    /// running under test.
    @Test func theTestHostNeverBringsUpAMenuBar() {
        #expect(MenuBarPresence.isRunningUnderTest)

        MenuBarPresence.startIfAvailable()

        #expect(!MenuBarPresence.isActive)
    }

    /// Starting on a platform with no menu bar, starting twice, and stopping
    /// something that was never started are all no-ops. The menu bar is an
    /// optional extra on one platform; nothing about it may ever be load-
    /// bearing for the app's launch.
    @Test func theMenuBarIsOptionalEverywhere() {
        MenuBarPresence.startIfAvailable()
        MenuBarPresence.startIfAvailable()
        MenuBarPresence.stop()
        MenuBarPresence.stop()

        #expect(!MenuBarPresence.isActive)
    }

    /// Summoning posts to the same one-slot mailbox the launchers use, so the
    /// menu bar inherits the tested focus rule instead of a second copy of it.
    @Test func summoningPostsTheNonClearingRequest() {
        let inbox = LaunchRequestInbox.shared
        _ = inbox.takePendingRequest()

        MenuBarPresence.summon()

        #expect(inbox.takePendingRequest() == .summonWithoutReset)
    }
}
