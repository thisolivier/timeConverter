import Carbon.HIToolbox
import Foundation
import Testing

// No `import` of the app: `GlobalHotKey.swift` and `SummonPolicy.swift` are
// *members of this target too* (see `project.yml`), exactly as
// `ConvertATimeIntent.swift` is shared with the Controls extension on iOS. The
// alternative is a host-application test bundle, which would launch the real
// menu-bar app — putting a status item in the menu bar and grabbing ⌃⌥T for
// the length of a unit-test run, which is a side effect no test asked for.
//
/// The parts of the Mac shell that can be proven without a menu bar.
///
/// Successor to the retired `MenuBarPlugInTests`, which tested the one thing
/// the Catalyst architecture could get wrong invisibly: the `@objc` protocol
/// cast across a loaded bundle. That whole failure mode is gone — there is no
/// bundle and no cast — so what is worth asserting instead is the chord itself
/// and the toggle rule.
///
/// The status item, the real ⌃⌥T registration and the panel are platform glue
/// verified by launching (`scripts/qa-menubar.sh`, plus one manual keypress).
/// `@MainActor` because `GlobalHotKey` is: the Carbon headers mark these calls
/// "not thread safe", so even its constants are main-actor-isolated, and
/// reading them from a nonisolated test is a compile error rather than a
/// warning under Swift 6. Annotating the suite is cheaper than loosening the
/// isolation on the production type.
@MainActor
struct GlobalHotKeyChordTests {
    /// The classic bug in this corner of the OS: Carbon's modifier bitmask and
    /// `NSEvent.ModifierFlags` are different families with overlapping-looking
    /// values, and mixing them silently registers the *wrong chord* while still
    /// returning `noErr`. ⌃⌥ is `0x1800` in Carbon and `0x0C0000` in AppKit, so
    /// this is the assertion that catches a "fix" that swaps them.
    @Test func theChordIsControlOptionInCarbonModifiers() {
        #expect(GlobalHotKey.modifiers == UInt32(controlKey | optionKey))
        #expect(GlobalHotKey.modifiers == 0x1800)
    }

    /// ⌃⌥T, decided 2026-10-21 ("T for time") over ⌃⌥Space, which the collision
    /// probe showed would have clashed. `kVK_ANSI_T` is a physical key
    /// *position*, which is why the constant is checked rather than a letter.
    @Test func theChordIsTheDecidedTKey() {
        #expect(GlobalHotKey.keyCode == UInt32(kVK_ANSI_T))
        #expect(GlobalHotKey.keyCode == 17)
    }

    /// Every registration outcome has to read as a sentence in the log, because
    /// that string is the only evidence `scripts/qa-menubar.sh` has — and the
    /// script greps for "⌃⌥T" specifically on the success path.
    @Test func everyRegistrationOutcomeDescribesItself() {
        #expect(GlobalHotKey.Registration.registered.description == "⌃⌥T")
        #expect(GlobalHotKey.Registration.alreadyTaken.description.contains("already taken"))
        #expect(GlobalHotKey.Registration.failed(-50).description.contains("-50"))
        // A failure must never *look* like a success to the QA grep.
        #expect(!GlobalHotKey.Registration.alreadyTaken.description.hasPrefix("⌃⌥T"))
    }
}

struct SummonPolicyTests {
    /// Pressing the key while looking at the panel puts it away. That is what
    /// makes ⌃⌥T a toggle rather than a "show" button.
    @Test func pressingAgainWhileLookingAtItHidesIt() {
        #expect(SummonPolicy.action(panelIsVisible: true, appIsActive: true) == .hide)
    }

    /// The case the one-parameter version of this rule got wrong: the panel is
    /// open but behind the user's editor, so they press ⌃⌥T to *reach* it.
    /// Hiding there makes the hotkey look broken.
    @Test func pressingFromAnotherAppBringsItForwardRatherThanHidingIt() {
        #expect(SummonPolicy.action(panelIsVisible: true, appIsActive: false) == .show)
    }

    @Test func pressingWithNothingOnScreenShowsIt() {
        #expect(SummonPolicy.action(panelIsVisible: false, appIsActive: false) == .show)
        #expect(SummonPolicy.action(panelIsVisible: false, appIsActive: true) == .show)
    }

    /// Repeated presses must alternate rather than drift into one state: three
    /// presses from nothing-on-screen end up showing, not hidden.
    @Test func repeatedPressesAlternate() {
        var panelIsVisible = false
        var actions: [SummonPolicy.Action] = []
        for _ in 0..<3 {
            let action = SummonPolicy.action(panelIsVisible: panelIsVisible, appIsActive: true)
            actions.append(action)
            panelIsVisible = action == .show
        }
        #expect(actions == [.show, .hide, .show])
    }
}

struct MacMenuBarLogTests {
    /// The log identity is a contract with two shell scripts: `run-mac.sh` and
    /// `qa-menubar.sh` both filter the unified log on exactly this pair, and it
    /// is deliberately the same pair the Catalyst build used so the QA lane
    /// survived the restructure.
    @Test func theLogIdentityMatchesWhatTheScriptsFilterOn() {
        #expect(MacMenuBarLog.subsystem == "dev.thisolivier.timeconverter")
        #expect(MacMenuBarLog.category == "menubar")
    }
}
