import Testing
import Foundation
@testable import TimeConverterCore

/// The UI glue. These are unit tests on the presenter's strings, not UI tests:
/// the view is a dumb switch over `ConverterDisplayState`, so covering the
/// presenter covers the interface's behaviour.
struct ConverterPresenterTests {
    private let presenter = ConverterPresenter()

    // MARK: Quiet by default

    @Test(arguments: ["", " ", "   \n\t "])
    func emptyInputStaysOnTheHint(input: String) {
        #expect(presenter.displayState(for: input, now: FixedDates.winterMidday) == .hint)
    }

    // MARK: Converted results

    @Test func convertedResultShowsTheCanonicalEchoAndTheZonesUsed() {
        let state = presenter.displayState(for: "12pm ET in London", now: FixedDates.winterMidday)
        #expect(state == .converted(ConverterDisplay(
            echoLine: "12:00 pm Eastern Time (New York, Toronto, UTC-5) "
                + "→ 5:00 pm London (UTC+0)",
            detailLine: "America/New_York → Europe/London",
            sourceEchoLine: "Eastern Time (New York, Toronto) · 12:00 PM",
            sourcePlaceName: "ET (Eastern Time)",
            sourceClockDigits: "12:00",
            sourceMeridiem: "PM",
            sourceZoneLine: "New York, Toronto",
            targetPlaceLabel: "In London",
            targetPlaceName: "London",
            targetClockDigits: "5:00",
            targetMeridiem: "PM",
            targetZoneLine: "United Kingdom Time (London)",
            footerSentence: "London is 5 hours ahead of Eastern Time.",
            offsetPhrase: "5 hours ahead",
            daylightSavingNote: nil
        )))
    }

    /// The rollover marker is part of the echo line, so it needs no special
    /// handling in the view.
    @Test func dayRolloverMarkerAppearsInTheEchoLine() throws {
        let state = presenter.displayState(
            for: "11pm new york to tokyo",
            now: FixedDates.winterMidday
        )
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(display.echoLine.hasSuffix("+1d"))
    }

    @Test func backwardRolloverMarkerAlsoAppears() throws {
        let state = presenter.displayState(
            for: "1am tokyo to new york",
            now: FixedDates.winterMidday
        )
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(display.echoLine.hasSuffix("-1d"))
    }

    /// Porto echoes as Lisbon — the detail line names the zone actually used,
    /// which is the whole point of echoing back.
    @Test func detailLineNamesTheResolvedZonesNotTheTypedTokens() throws {
        let state = presenter.displayState(for: "23:15 UK to Porto", now: FixedDates.winterMidday)
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(display.detailLine == "Europe/London → Europe/Lisbon")
    }

    // MARK: DST notes

    @Test func nonexistentTimeIsExplainedInTheDetailLine() throws {
        let state = presenter.displayState(
            for: "2:30 am ET in London",
            now: FixedDates.newYorkSpringForwardDay
        )
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(display.echoLine == "3:00 am Eastern Time (New York, Toronto, UTC-4) "
            + "→ 7:00 am London (UTC+0)")
        // The DST note names the plain city even though the echo expanded the
        // abbreviation — "doesn't exist today in Eastern Time (…)" does not read.
        #expect(display.detailLine == "America/New_York → Europe/London · "
            + "2:30 am doesn't exist today in New York — clocks went forward")
    }

    @Test func repeatedTimeIsExplainedInTheDetailLine() throws {
        let state = presenter.displayState(
            for: "1:30 am ET in London",
            now: FixedDates.newYorkFallBackDay
        )
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(display.detailLine == "America/New_York → Europe/London · "
            + "1:30 am happens twice today in New York — showing the first")
    }

    @Test func ordinaryConversionsCarryNoDaylightSavingNote() throws {
        let state = presenter.displayState(for: "12pm ET in London", now: FixedDates.winterMidday)
        guard case let .converted(display) = state else {
            Issue.record("expected a conversion")
            return
        }
        #expect(!display.detailLine.contains("·"))
    }

    // MARK: Prompts render as one plain line

    /// P3 is retired, so the single-zone strings that used to stand for it are
    /// now conversions; `3pm in` takes its place as the other way to name no
    /// zone at all. P1's stand-in is `12` rather than `hello there`, which
    /// item 22 turned into a bare-zone P5.
    @Test(arguments: [
        ("12", "P1"),
        ("3pm", "P2"),
        ("3pm in", "P2"),
        ("9am CST in London", "P4"),
        ("9am Narnia in London", "P5"),
        ("Lodnon", "P5"),
    ])
    func everyPromptBecomesAProblemLine(input: String, specIdentifier: String) throws {
        let state = presenter.displayState(for: input, now: FixedDates.winterMidday)
        guard let message = state.problemMessage else {
            Issue.record("expected \(specIdentifier) to render as a problem")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func plainPromptsUseTheirSpecCopyUnchanged() {
        #expect(presenter.displayState(for: "12", now: FixedDates.winterMidday)
            == plainProblem("Couldn't find a time — start with e.g. 14:30 or 2:30 pm"))
        #expect(presenter.displayState(for: "3pm", now: FixedDates.winterMidday)
            == plainProblem("Convert 3:00 pm where? Add a timezone, city, or country"))
    }

    /// The inline candidate list stays exactly as it was: the chip row is
    /// additive, and prompt copy is explicitly out of scope until the design
    /// sprint.
    @Test func ambiguityPromptListsItsCandidatesInline() {
        #expect(presenter.displayState(for: "9am CST in London", now: FixedDates.winterMidday)
            .problemMessage == "'cst' could mean more than one place — pick one: "
                + "Chicago (UTC-6), Shanghai (UTC+8)")
    }

    @Test func ambiguityPromptListsAllSixUnitedStatesZones() throws {
        let state = presenter.displayState(for: "9am USA to London", now: FixedDates.winterMidday)
        let message = try #require(state.problemMessage)
        for city in ["New York", "Chicago", "Denver", "Los Angeles", "Anchorage", "Honolulu"] {
            #expect(message.contains(city))
        }
    }

    // MARK: Launch argument

    /// A suite name of its own, like every other launch-argument test: Swift
    /// Testing runs these in parallel, and the sibling test below shared this
    /// one's `UserDefaults` suite until it started flaking — its `defer`
    /// cleanup was deleting this test's prefill mid-read.
    @Test func launchArgumentPrefillIsReadFromUserDefaults() throws {
        let defaults = try #require(
            UserDefaults(suiteName: "ConverterPresenterTests.prefill")
        )
        defer { defaults.removeObject(forKey: LaunchArguments.initialInputKey) }

        #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)

        defaults.set("12pm ET in London", forKey: LaunchArguments.initialInputKey)
        #if DEBUG
        #expect(LaunchArguments.initialInput(readingFrom: defaults) == "12pm ET in London")
        #else
        // Release builds must ignore the argument entirely.
        #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)
        #endif
    }

    @Test func blankLaunchArgumentIsTreatedAsAbsent() throws {
        let defaults = try #require(
            UserDefaults(suiteName: "ConverterPresenterTests.blankPrefill")
        )
        defer { defaults.removeObject(forKey: LaunchArguments.initialInputKey) }

        defaults.set("   ", forKey: LaunchArguments.initialInputKey)
        #expect(LaunchArguments.initialInput(readingFrom: defaults) == nil)
    }

    /// The prefilled value must flow through the presenter to a real
    /// conversion, which is what makes a headless screenshot meaningful.
    @Test func aPrefilledInputConvertsOnFirstRender() {
        let prefilledInput = "9:30 am New York to Lisbon"
        let state = presenter.displayState(for: prefilledInput, now: FixedDates.winterMidday)
        #expect(state == .converted(ConverterDisplay(
            echoLine: "9:30 am New York (UTC-5) → 2:30 pm Lisbon (UTC+0)",
            detailLine: "America/New_York → Europe/Lisbon",
            sourceEchoLine: "New York · 9:30 AM",
            sourcePlaceName: "New York",
            sourceClockDigits: "9:30",
            sourceMeridiem: "AM",
            sourceZoneLine: "Eastern Time (New York, Toronto)",
            targetPlaceLabel: "In Lisbon",
            targetPlaceName: "Lisbon",
            targetClockDigits: "2:30",
            targetMeridiem: "PM",
            targetZoneLine: "Western European Time (Lisbon)",
            footerSentence: "Lisbon is 5 hours ahead of New York.",
            offsetPhrase: "5 hours ahead",
            daylightSavingNote: nil
        )))
    }

    // MARK: - The redesigned layout's slots (item 18)

    /// The design's own example, end to end, on a date where the real zones
    /// produce the mockup's own numbers: everything the poster layout draws
    /// comes off one parse, and the box echo is the source side only — now
    /// without the design's own `· UTC+1`, which item 21 removed.
    ///
    /// Spelled without the diacritic because that is what today's parser
    /// resolves — `São Paulo` currently lands on P5 and offers `Sao Paulo?` as
    /// a chip. That gap belongs to backlog item 6 (QA candidates, punctuation
    /// and accents), not to the design sprint, so it is recorded rather than
    /// quietly fixed here.
    @Test func theDesignsOwnExampleFillsEverySlot() throws {
        let state = presenter.displayState(
            for: "8pm Lisbon in Sao Paulo",
            now: FixedDates.summerMidday
        )
        let display = try #require(state.convertedDisplay)
        #expect(display.sourceEchoLine == "Lisbon · 8:00 PM")
        #expect(display.targetPlaceLabel == "In Sao Paulo")
        #expect(display.targetClockDigits == "4:00")
        #expect(display.targetMeridiem == "PM")
        #expect(display.targetZoneLine == "Brasilia Standard Time (São Paulo)")
        #expect(display.footerSentence == "Sao Paulo is 4 hours behind Lisbon.")
    }

    /// A defaulted side stays visible in the redesign: the `(local)` marker
    /// survives into both the box echo and the result label, because an
    /// assumption the user cannot see is the one bug this app cannot afford.
    @Test func aDefaultedSourceKeepsItsLocalMarkerInTheBoxEcho() throws {
        let state = presenter.displayState(
            for: "7pm in London",
            now: FixedDates.winterMidday,
            localZone: TimeZone(identifier: "America/Los_Angeles")!
        )
        let display = try #require(state.convertedDisplay)
        #expect(display.sourceEchoLine == "Los Angeles (local) · 7:00 PM")
        #expect(display.targetPlaceLabel == "In London")
        #expect(display.footerSentence == "London is 8 hours ahead of Los Angeles.")
    }

    @Test func aDefaultedTargetKeepsItsLocalMarkerInTheResultLabel() throws {
        let state = presenter.displayState(
            for: "7pm London",
            now: FixedDates.winterMidday,
            localZone: TimeZone(identifier: "America/Los_Angeles")!
        )
        let display = try #require(state.convertedDisplay)
        #expect(display.targetPlaceLabel == "In Los Angeles (local)")
    }

    /// The rollover cannot simply vanish because the new layout has no echo
    /// sentence to carry `+1d`, so it rides the zone line instead — and it had
    /// to survive item 21 taking the UTC offset off that line with it.
    @Test func theDayRolloverRidesTheZoneLine() throws {
        let forward = try #require(
            presenter.displayState(for: "11pm new york to tokyo", now: FixedDates.winterMidday)
                .convertedDisplay
        )
        #expect(forward.targetZoneLine == "Japan Standard Time (Tokyo) · next day")

        let backward = try #require(
            presenter.displayState(for: "1am tokyo to new york", now: FixedDates.winterMidday)
                .convertedDisplay
        )
        #expect(backward.targetZoneLine == "Eastern Time (New York, Toronto) · previous day")
    }

    /// The DST explanation moves out of `detailLine` into a slot of its own so
    /// the redesign can place it, and is `nil` the other 363 days of the year.
    @Test func theDaylightSavingNoteIsItsOwnField() throws {
        let onATransitionDay = try #require(
            presenter.displayState(
                for: "2:30 am ET in London",
                now: FixedDates.newYorkSpringForwardDay
            ).convertedDisplay
        )
        #expect(onATransitionDay.daylightSavingNote
            == "2:30 am doesn't exist today in New York — clocks went forward")

        let ordinary = try #require(
            presenter.displayState(for: "12pm ET in London", now: FixedDates.winterMidday)
                .convertedDisplay
        )
        #expect(ordinary.daylightSavingNote == nil)
    }

    /// Midnight and noon are where a naive digits/meridiem split goes wrong.
    @Test(arguments: [
        ("12am London to London", "12:00", "AM"),
        ("12pm London to London", "12:00", "PM"),
    ])
    func theClockSplitsIntoDigitsAndMeridiem(
        input: String,
        expectedDigits: String,
        expectedMeridiem: String
    ) throws {
        let display = try #require(
            presenter.displayState(for: input, now: FixedDates.winterMidday).convertedDisplay
        )
        #expect(display.targetClockDigits == expectedDigits)
        #expect(display.targetMeridiem == expectedMeridiem)
    }
}
