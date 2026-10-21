import SwiftUI

/// Item 10 — when the app puts the keyboard up by itself.
///
/// Extracted from `ContentView` so the one judgement call in it is a tested
/// rule rather than an inline `guard`: **focus on arrival, never mid-session.**
///
/// For a typed-input tool, launch-to-typing *is* the access story, so launch and
/// a genuine return from the background both focus the field. A `.inactive`
/// phase does not, and that distinction is the whole point on Mac Catalyst,
/// where merely clicking another window drops the scene to `.inactive` and
/// clicking back raises it again. Treating that as "arrival" would yank focus
/// out from under a user who was doing something else on the same machine.
enum InputFocusPolicy {
    /// Launch (and the DEBUG `-initialInput` prefill): always focus. The
    /// prefilled text stays put; focusing only places the cursor in it.
    static let shouldFocusOnAppear = true

    /// Whether a scene-phase transition counts as arriving at the app.
    static func shouldFocusInput(
        movingFrom previousPhase: ScenePhase,
        to currentPhase: ScenePhase
    ) -> Bool {
        currentPhase == .active && previousPhase == .background
    }
}
