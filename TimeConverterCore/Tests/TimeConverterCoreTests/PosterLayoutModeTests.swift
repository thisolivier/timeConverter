import Testing
import Foundation
@testable import TimeConverterCore

/// Backlog item 19 — the collapse decision.
///
/// The animation and the keyboard observation are platform glue that only a
/// running app can prove, and are verified by launching it. What *is* testable
/// is the rule itself, and it is the part with a judgement in it: an empty
/// field with the keyboard up must keep the full poster, which is the one
/// quadrant of the truth table someone would plausibly get wrong.
struct PosterLayoutModeTests {
    /// The whole truth table, all four quadrants, in the order they read.
    @Test(arguments: [
        (false, false, PosterLayoutMode.full),
        (true, false, PosterLayoutMode.full),
        // Agreed explicitly: "when there's no input, current behavior is fine".
        // The title is the only thing worth looking at on an empty screen.
        (false, true, PosterLayoutMode.full),
        (true, true, PosterLayoutMode.compact),
    ])
    func theCollapseRuleIsOnlyTrueInOneQuadrant(
        hasInput: Bool,
        keyboardIsVisible: Bool,
        expectedMode: PosterLayoutMode
    ) {
        #expect(PosterLayoutMode.mode(
            hasInput: hasInput, keyboardIsVisible: keyboardIsVisible
        ) == expectedMode)
    }

    /// Whitespace is not input. A stray space from a paste or an autocorrect
    /// must not eat the title — and it is also what `ConverterPresenter`
    /// already treats as empty, so the two agree about what "nothing typed"
    /// means.
    @Test(arguments: ["", " ", "   \n\t "])
    func whitespaceOnlyInputCountsAsEmpty(rawInput: String) {
        #expect(PosterLayoutMode.mode(forInput: rawInput, keyboardIsVisible: true) == .full)
    }

    @Test(arguments: ["8", "8pm", "8pm Lisbon in Sao Paulo", " 8pm "])
    func anythingElseCountsAsInput(rawInput: String) {
        #expect(PosterLayoutMode.mode(forInput: rawInput, keyboardIsVisible: true) == .compact)
        // …and the keyboard being down always wins, because then there is room.
        #expect(PosterLayoutMode.mode(forInput: rawInput, keyboardIsVisible: false) == .full)
    }

    /// The title and the rule under it travel together: the rule exists to
    /// close the title block, and a line ruled under nothing is worse than no
    /// line at all.
    @Test func theTitleBlockShowsOnlyInTheFullLayout() {
        #expect(PosterLayoutMode.full.showsTitleBlock)
        #expect(!PosterLayoutMode.compact.showsTitleBlock)
    }

    @Test func onlyTheCompactLayoutStepsTheResultTypeDown() {
        #expect(!PosterLayoutMode.full.usesCompactResultType)
        #expect(PosterLayoutMode.compact.usesCompactResultType)
    }

    /// Two modes, and the test says so: a third ("medium") would mean the view
    /// has to choose, and the whole point of the enum is that it doesn't.
    @Test func thereAreExactlyTwoModes() {
        #expect(PosterLayoutMode.allCases == [.full, .compact])
    }
}
