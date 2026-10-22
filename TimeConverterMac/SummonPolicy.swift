import Foundation
import os

/// What ⌃⌥T (or a click on the clock glyph) should actually do, given what is
/// already on screen.
///
/// Extracted from `PanelSummoner` for the same reason `InputFocusPolicy` is
/// extracted from the iOS `ContentView`: it is the one judgement call in the
/// summon path, and `NSPanel` itself cannot be unit-tested headlessly.
enum SummonPolicy {
    enum Action: Equatable {
        /// Create or raise the panel, activate the app, focus the field.
        case show
        /// Put it away again — the hotkey is a toggle.
        case hide
    }

    /// The rule, in one line: **a toggle only toggles when you can already see
    /// it.**
    ///
    /// Visible *and* ours is the frontmost app: the user is looking at the
    /// panel and pressed the key again, so they want it gone. Visible but
    /// another app is active: the panel is sitting behind someone else's
    /// window, and "hide" would read as the hotkey doing nothing — so bring it
    /// forward instead. This is the whole reason the policy takes two
    /// parameters rather than one.
    static func action(panelIsVisible: Bool, appIsActive: Bool) -> Action {
        panelIsVisible && appIsActive ? .hide : .show
    }
}

/// Shared logging identity for the Mac shell.
///
/// Same subsystem the Catalyst build used, and the same `menubar` category, so
/// `scripts/qa-menubar.sh` and `scripts/run-mac.sh` keep their one log
/// predicate across the restructure.
enum MacMenuBarLog {
    static let subsystem = "dev.thisolivier.timeconverter"
    static let category = "menubar"

    static let logger = Logger(subsystem: subsystem, category: category)
}
