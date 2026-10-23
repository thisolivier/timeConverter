import Foundation

/// How much poster there is room for — backlog item 19's keyboard
/// choreography.
///
/// The decision is a pure function of two facts, and that is the whole reason
/// this type exists on the core side of the line: the iOS view owns the
/// *observation* (is the keyboard up?) and the *animation*, neither of which a
/// unit test can see, but the rule itself is testable and is where the
/// judgement lives.
///
/// ## The rule
///
/// Collapse only when the user is **typing into something**. An empty field
/// with the keyboard up is the app's opening state and keeps the full poster —
/// agreed explicitly: "when there's no input, current behavior is fine". The
/// title is the only thing on screen worth looking at then. Once there is
/// input there is also a result, the result is the thing being read, and the
/// title is what the keyboard is allowed to eat.
public enum PosterLayoutMode: Equatable, Sendable, CaseIterable {
    /// The poster as designed: title, top rule, full-scale numerals.
    case full
    /// Title and top rule gone, numerals a step down, so the input box through
    /// the footer all fit above the keyboard.
    case compact

    /// The decision. `rawInput` is the field's exact contents — whitespace
    /// only still counts as empty, because a stray space is not input.
    public static func mode(forInput rawInput: String, keyboardIsVisible: Bool) -> PosterLayoutMode {
        let hasInput = !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return mode(hasInput: hasInput, keyboardIsVisible: keyboardIsVisible)
    }

    /// The same decision with the string already reduced to a fact, which is
    /// the form the truth table reads best in.
    public static func mode(hasInput: Bool, keyboardIsVisible: Bool) -> PosterLayoutMode {
        hasInput && keyboardIsVisible ? .compact : .full
    }

    /// `TIME / CONVERTER` and the 2pt rule under it travel together: the rule
    /// exists to close the title block, so keeping it after the title has gone
    /// would leave a line ruled under nothing.
    public var showsTitleBlock: Bool { self == .full }

    /// The result numerals step down rather than scale freely — see
    /// `PosterResultSection`, which owns the two sizes.
    public var usesCompactResultType: Bool { self == .compact }
}
