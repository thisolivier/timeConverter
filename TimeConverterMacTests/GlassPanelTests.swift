import AppKit
import Foundation
import Testing
import TimeConverterCore
import TimeConverterUI

// `GlassPanelLayout.swift` and `MacAppearanceOverride.swift` are members of
// this target as well as of the app, the same arrangement `SummonPolicy.swift`
// and `GlobalHotKey.swift` already use — see the note at the top of
// `MacShellTests.swift`. Both were written view-free precisely so they could
// be: the glass panel's two real decisions are "which container am I in" and
// "which section does this state route to", and neither needs a window.

/// Backlog item 20, phase B — the glass panel.
///
/// What is worth asserting here is the same thing phase A asserted about the
/// shared layer: not the pixels, but the arithmetic and the routing underneath
/// them. Three things actually break.
///
/// 1. The dropdown is supposed to stack *because the pair does not fit*, not
///    because someone typed `.stacked` next to it. That is a derivation, and a
///    derivation can be wrong.
/// 2. The panel is supposed to be the design's 740pt and not resizable.
/// 3. Every display state has to land somewhere, including the two that the
///    design never drew.
@MainActor
struct GlassPresentationTests {
    /// The design's own width, unmodified, and the `.wide` metrics the panel
    /// is built from. A drift here is a drift away from page 3.
    @Test func theSummonedPanelIsTheDesignsOwnWidth() {
        #expect(GlassPresentation.summonedPanel.metrics.totalWidth == 740)
        #expect(GlassPresentation.summonedPanel.metrics == .wide)
    }

    /// The two containers differ, and differ in all three of the ways the
    /// presentation is allowed to differ. If a refactor ever collapsed them
    /// onto one set of values, this is the test that would notice.
    @Test func theTwoContainersDisagreeAboutWidthGlassAndInstructions() {
        let panel = GlassPresentation.summonedPanel
        let dropdown = GlassPresentation.menuBarDropdown

        #expect(panel.metrics.totalWidth > dropdown.metrics.totalWidth)
        #expect(panel.surfaceStyle == .floatingWindow)
        // The dropdown is already sitting on AppKit's own material, so drawing
        // a second panel inside it would be a panel inside a panel.
        #expect(dropdown.surfaceStyle == .hostedInSystemMaterial)
        #expect(panel.needsDismissalHint)
        #expect(!dropdown.needsDismissalHint)
    }

    /// The selection rule, from the panel's end: 740pt is comfortably enough
    /// for the design, so the panel gets the design — side by side, at the
    /// design's own size step, with nothing shrunk.
    @Test func thePanelDrawsTheDesignSideBySideAtFullScale() {
        let metrics = GlassPresentation.summonedPanel.metrics
        #expect(metrics.pairAxis == .sideBySide)
        #expect(metrics.pairScale == .full)
    }

    /// The selection rule, from the dropdown's end. A menu-bar popover is
    /// around 400pt wide; the pair needs about 600 at full scale and about 440
    /// at compact, so neither fits and it stacks. Side by side there would mean
    /// `minimumScaleFactor` shrinking 124pt numerals to caption size, which is
    /// not a smaller version of the poster — it is the poster destroyed.
    @Test func theDropdownStacksBecauseThePairGenuinelyDoesNotFit() {
        let metrics = GlassPresentation.menuBarDropdown.metrics
        #expect(metrics.pairAxis == .stacked)
        #expect(metrics.contentWidth < ConversionPairScale.compact.minimumSideBySideWidth)
    }

    /// Padding has to leave something to draw in. Trivially true today and
    /// trivially false the first time someone widens the panel's padding
    /// without looking at its width.
    @Test(arguments: GlassPresentation.allCases)
    func everyPresentationHasUsableContentWidth(presentation: GlassPresentation) {
        let metrics = presentation.metrics
        #expect(metrics.contentWidth > 0)
        #expect(metrics.contentWidth < metrics.totalWidth)
    }
}

/// Which section of the panel a display state lands in.
@MainActor
struct GlassResultRoutingTests {
    /// Real states from the real driver rather than hand-built values: the
    /// display types' memberwise initialisers are internal to the package, and
    /// going through the driver means a test that routes at all is also proof
    /// the parse still works. The same discipline the phase-A previews use.
    private func state(for input: String) -> ConverterDisplayState {
        let driver = ConverterDisplayDriver()
        driver.showWithoutWaiting(for: input, now: Date(), localZone: TimeZone(identifier: "Europe/Lisbon")!)
        return driver.displayState
    }

    @Test func anEmptyFieldRoutesToTheHint() {
        #expect(GlassResultSection.routing(for: state(for: "")) == .hint)
    }

    /// The happy path, which is the only one the design draws.
    @Test func aConversionRoutesToThePair() {
        let section = GlassResultSection.routing(for: state(for: "8pm Lisbon in Sao Paulo"))
        guard case let .pair(display) = section else {
            Issue.record("expected the pair, got \(section)")
            return
        }
        // Both sides are populated — the source column's slots are what phase A
        // added to the core, and a pair view with an empty FROM column is the
        // way that addition would regress.
        #expect(!display.sourcePlaceName.isEmpty)
        #expect(!display.targetPlaceName.isEmpty)
        #expect(!display.footerSentence.isEmpty)
        #expect(!section.showsChips)
    }

    /// P1: nothing that parses as a time. No token to rewrite, so no chips.
    @Test func anUnparseableSentenceRoutesToAPromptWithNoChips() {
        let section = GlassResultSection.routing(for: state(for: "hello there"))
        guard case let .prompt(problem) = section else {
            Issue.record("expected a prompt, got \(section)")
            return
        }
        #expect(!problem.message.isEmpty)
        #expect(!section.showsChips)
    }

    /// P4/P5: a zone token the parser cannot pin down. These are the prompts
    /// with corrections attached, and the chips have to survive the trip to the
    /// glass styling — `showsChips` is what the layout asks before drawing the
    /// flow row.
    @Test func anUnrecognisedZoneRoutesToAPromptThatOffersChips() {
        let section = GlassResultSection.routing(for: state(for: "8pm Lisbon in Lundon"))
        guard case .prompt = section else {
            Issue.record("expected a prompt, got \(section)")
            return
        }
        #expect(section.showsChips)
    }
}

/// The footer's two-input rule.
@MainActor
struct GlassFooterTextTests {
    private func convertedSection() -> GlassResultSection {
        let driver = ConverterDisplayDriver()
        driver.showWithoutWaiting(
            for: "8pm Lisbon in Sao Paulo",
            now: Date(),
            localZone: TimeZone(identifier: "Europe/Lisbon")!
        )
        return GlassResultSection.routing(for: driver.displayState)
    }

    /// When there is a conversion, the footer is the design's sentence — the
    /// target-named one ("São Paulo is 4 hours behind Lisbon."), which is
    /// working assumption 2 of the sprint plan, and it is the sentence in both
    /// containers.
    @Test(arguments: GlassPresentation.allCases)
    func aConversionPutsTheDesignsSentenceInTheFooter(presentation: GlassPresentation) {
        let section = convertedSection()
        guard case let .pair(display) = section else {
            Issue.record("expected the pair")
            return
        }
        #expect(
            GlassFooterText.text(for: section, presentation: presentation)
                == display.footerSentence
        )
    }

    /// With no sentence to show, the panel uses the line to say how to put
    /// itself away — it has no title bar and no close button, so this is the
    /// only place that information exists.
    @Test func thePanelExplainsItselfWhenThereIsNoSentence() {
        let hint = GlassFooterText.text(for: .hint, presentation: .summonedPanel)
        #expect(hint == GlassFooterText.dismissalHint)
        // It names both ways out, because esc belongs to the text field while
        // the field is mid-edit and does not always reach the window.
        #expect(hint.contains("⌃⌥T"))
        #expect(hint.lowercased().contains("esc"))
    }

    /// The dropdown needs no instructions: clicking away from a menu-bar
    /// popover is something every Mac user already knows, and printing a hint
    /// about a hotkey there would be noise.
    @Test func theDropdownSaysNothingWhenThereIsNoSentence() {
        #expect(GlassFooterText.text(for: .hint, presentation: .menuBarDropdown).isEmpty)
    }

    /// The daylight-saving note rides with the conversion and nothing else —
    /// there is no note to attach to a prompt.
    @Test func onlyAConversionCanCarryADaylightSavingNote() {
        #expect(GlassFooterText.note(for: .hint) == nil)
    }
}

/// The QA appearance override.
///
/// It exists because the glass palette's dark values are *derived* rather than
/// designed, so they need looking at — and "switch the whole Mac to dark mode
/// and back" is enough friction that it does not get done.
struct MacAppearanceOverrideTests {
    private func defaults(_ value: String?) -> UserDefaults {
        let suiteName = "glass-appearance-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        if let value { defaults.set(value, forKey: MacAppearanceOverride.key) }
        return defaults
    }

    @Test func bothAppearancesCanBeAskedForByName() {
        #expect(MacAppearanceOverride.requestedAppearance(readingFrom: defaults("dark")) == .darkAqua)
        #expect(MacAppearanceOverride.requestedAppearance(readingFrom: defaults("light")) == .aqua)
    }

    /// Case-insensitive, because the person typing it at a shell prompt is not
    /// thinking about case.
    @Test func theNameIsNotCaseSensitive() {
        #expect(MacAppearanceOverride.requestedAppearance(readingFrom: defaults("Dark")) == .darkAqua)
    }

    /// The overwhelmingly common case, and the one that matters: with no
    /// argument the app must not pin an appearance at all, or it would stop
    /// following the system setting for every ordinary launch.
    @Test func nothingIsForcedWhenNothingIsAsked() {
        #expect(MacAppearanceOverride.requestedAppearance(readingFrom: defaults(nil)) == nil)
        #expect(MacAppearanceOverride.requestedAppearance(readingFrom: defaults("mauve")) == nil)
    }
}
