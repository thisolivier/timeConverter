import Foundation
import Observation
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

    /// Whether this action should also put the cursor in the input field
    /// (backlog item 17).
    ///
    /// Every `.show` does, including the one that merely raises an
    /// already-open panel from behind another app — that press means "I want
    /// to type a time", and arriving at a visible panel that ignores the
    /// keyboard is the exact complaint item 17 came from. `.hide` obviously
    /// does not.
    static func requestsInputFocus(for action: Action) -> Bool {
        action == .show
    }
}

/// The summoner's one message to the view: *a summon just happened*.
///
/// `PanelSummoner` is AppKit and cannot write SwiftUI's `@FocusState`, so it
/// raises a flag the view watches instead.
///
/// A counter rather than a `Bool`, because the awkward case is the **second**
/// summon in a row: ⌃⌥T while the panel is already open but buried behind the
/// editor has to re-focus the field, and `true → true` is not a change
/// SwiftUI's `onChange` will ever deliver. A monotonically increasing value
/// always changes.
///
/// Shared rather than injected because the two ends never meet: the panel's
/// content is built inside an `NSHostingView` and the dropdown's by the
/// `MenuBarExtra` scene.
@MainActor
@Observable
final class SummonFocusRequests {
    static let shared = SummonFocusRequests()

    /// Bumped once per summon. Only its *changes* carry meaning; the value
    /// itself is nothing.
    private(set) var requestCount: Int = 0

    func request() {
        requestCount += 1
    }
}

/// How hard the view tries to put the cursor in the field, and when it stops.
///
/// `@FocusState` only takes hold once the hosting view's window is key and
/// SwiftUI has installed its responder chain. Neither is guaranteed to have
/// happened when `onAppear` runs on a window AppKit is still ordering front,
/// so a single write lands *usually* — and "usually" is the bug item 17
/// reports.
///
/// The view therefore writes the focus more than once on a short ladder: now,
/// then after a turn of the run loop, then once more a few frames later. Each
/// attempt after a successful one is a no-op, because assigning `@FocusState`
/// the value it already holds changes nothing.
///
/// Extracted for the same reason `SummonPolicy` is: the judgement here is
/// "bounded, short, and finished before a human could reach the keyboard", and
/// that deserves to be asserted rather than buried in a view.
enum SummonFocusLadder {
    /// Delays measured from the moment focus is requested. Deliberately
    /// finite — a retry that never ends would fight the user for the cursor.
    static let attemptDelays: [Duration] = [
        .zero,
        .milliseconds(50),
        .milliseconds(200),
    ]

    /// When the last attempt fires.
    static var lastAttemptDelay: Duration {
        attemptDelays.last ?? .zero
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
