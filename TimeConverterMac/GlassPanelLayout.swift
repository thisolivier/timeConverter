import Foundation
import TimeConverterCore
import TimeConverterUI

/// Which of the Mac's two containers the converter is being drawn in — and
/// everything that follows from the answer.
///
/// The Mac shows the *same* converter twice: in a summoned floating panel and
/// in the menu-bar dropdown. Phase B's rule is that it is one view either way
/// (working assumption 3 of `docs/sprint-plan-ipad-mac.md`: "the dropdown gets
/// the same content adapted to its width"), so every difference between them
/// has to be a value one of these two cases hands over rather than a branch
/// somewhere in the drawing.
///
/// There are only three such values, which is the evidence the rule held: how
/// wide it is, who supplies the glass, and whether it has to tell you how to
/// get rid of it. The pair's axis and size step are *not* among them — those
/// fall out of the width by measurement, in `GlassPanelMetrics`.
enum GlassPresentation: String, Equatable, Sendable, CaseIterable {
    /// The ⌃⌥T panel: a transparent `NSPanel` floating over the desktop.
    case summonedPanel
    /// The `MenuBarExtra` dropdown, which AppKit has already made out of glass.
    case menuBarDropdown

    /// Page 3's 740pt for the panel; a dropdown-sized derivation for the other.
    var metrics: GlassPanelMetrics {
        switch self {
        case .summonedPanel: return .wide
        case .menuBarDropdown: return .narrow
        }
    }

    /// Who draws the frosting, the rim and the corners.
    var surfaceStyle: GlassPanelSurfaceStyle {
        switch self {
        case .summonedPanel: return .floatingWindow
        case .menuBarDropdown: return .hostedInSystemMaterial
        }
    }

    /// Whether the footer has to explain how to dismiss this thing.
    ///
    /// The panel does: it is summoned from inside another app by a chord, it
    /// has no title bar and no close button by design, and a glass rectangle
    /// with no visible exit is the kind of thing people force-quit. The
    /// dropdown does not — clicking away from a menu-bar popover is something
    /// every Mac user already knows.
    var needsDismissalHint: Bool { self == .summonedPanel }
}

/// What the middle section of the panel is showing.
///
/// A restatement of `ConverterDisplayState` in the panel's own terms, and it
/// earns the restatement: the Mac draws the converted case as the design's
/// side-by-side pair, which is a completely different view from the prompt,
/// and the mapping is the thing worth being able to assert without a window.
enum GlassResultSection: Equatable {
    /// Nothing typed, or a prompt still held back by the typing debounce.
    case hint
    /// The design's `FROM`/`TO` pair.
    case pair(ConverterDisplay)
    /// A prompt — P1, P2, P4 or P5 — with its chips, if it has any.
    case prompt(ConverterProblem)

    /// The whole of the panel's routing, in one place.
    static func routing(for state: ConverterDisplayState) -> GlassResultSection {
        switch state {
        case .hint: return .hint
        case let .converted(display): return .pair(display)
        case let .problem(problem): return .prompt(problem)
        }
    }

    /// Whether this section offers tap-to-replace corrections. P1 and P2 have
    /// no single token to rewrite and so offer none; P4 and P5 do.
    var showsChips: Bool {
        guard case let .prompt(problem) = self else { return false }
        return !problem.chips.isEmpty
    }
}

/// The line along the bottom of the panel, under the second hairline.
///
/// The design puts one thing there — the target-named sentence, `São Paulo is 4
/// hours behind Lisbon.` — because the design only draws the happy path. The
/// other two states have no sentence, and leaving the line blank was the wrong
/// answer for the panel specifically: that is the only state in which a user
/// who has just summoned a chromeless rectangle might want to know how to put
/// it away again.
///
/// So the footer carries the sentence when there is one and the dismissal hint
/// when there is not — and nothing at all in the dropdown, which needs no
/// instructions. Two inputs, one rule, no view required to test it.
enum GlassFooterText {
    /// The chord and the key, spelled the way the rest of the app spells them.
    static let dismissalHint = "⌃⌥T hides this panel · esc dismisses it"

    static func text(
        for section: GlassResultSection,
        presentation: GlassPresentation
    ) -> String {
        if case let .pair(display) = section {
            return display.footerSentence
        }
        return presentation.needsDismissalHint ? dismissalHint : ""
    }

    /// The daylight-saving explanation, on the two days a year it applies —
    /// set under the sentence rather than inside it, because it is a note about
    /// the conversion and not part of the relationship the sentence states.
    static func note(for section: GlassResultSection) -> String? {
        guard case let .pair(display) = section else { return nil }
        return display.daylightSavingNote
    }
}
