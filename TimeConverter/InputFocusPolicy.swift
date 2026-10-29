import SwiftUI

/// Item 10 — when the app puts the keyboard up by itself.
///
/// Extracted from `ContentView` so the one judgement call in it is a tested
/// rule rather than an inline `guard`: **focus on arrival, never mid-session.**
///
/// For a typed-input tool, launch-to-typing *is* the access story, so launch and
/// a genuine return from the background both focus the field. A `.inactive`
/// phase does not, and that distinction is the whole point on iPad
/// multitasking, where merely tapping another window drops the scene to
/// `.inactive` and tapping back raises it again. Treating that as "arrival"
/// would yank focus out from under a user who was doing something else on the
/// same screen. (It mattered on Mac Catalyst for the same reason; the Mac is
/// its own native target since item 16 and has its own focus story.)
enum InputFocusPolicy {
    /// Launch (and the DEBUG `-initialInput` prefill): always focus. The
    /// prefilled text stays put; focusing only places the cursor in it.
    ///
    /// Since the tabs (item 31) the Convert view *appears* again every time
    /// the user comes back from Clocks, and that is mid-session: they went to
    /// look at clocks, not to type, so the keyboard stays down (Olivier,
    /// 2026-10-29). Only the first appearance is launch.
    static func shouldFocusOnAppear(isFirstAppearance: Bool) -> Bool {
        isFirstAppearance
    }

    /// A launcher (App Shortcut phrase, Control Center control — backlog item
    /// 11) always focuses, even mid-session. Unlike a scene-phase change this
    /// is an explicit press of a button whose entire purpose is "let me type a
    /// time", so taking focus is obeying the user rather than interrupting one.
    static let shouldFocusOnLaunchRequest = true

    /// Whether a scene-phase transition counts as arriving at the app.
    static func shouldFocusInput(
        movingFrom previousPhase: ScenePhase,
        to currentPhase: ScenePhase
    ) -> Bool {
        currentPhase == .active && previousPhase == .background
    }
}
