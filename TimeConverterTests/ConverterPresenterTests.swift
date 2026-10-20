import Testing
import Foundation
@testable import TimeConverter

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
            echoLine: "12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0)",
            detailLine: "America/New_York → Europe/London"
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
        #expect(display.echoLine == "3:00 am New York (UTC-4) → 7:00 am London (UTC+0)")
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

    @Test(arguments: [
        ("hello there", "P1"),
        ("3pm in Tokyo", "P2"),
        ("06:34 Portugal", "P3"),
        ("9am CST in London", "P4"),
        ("9am Narnia in London", "P5"),
    ])
    func everyPromptBecomesAProblemLine(input: String, specIdentifier: String) throws {
        let state = presenter.displayState(for: input, now: FixedDates.winterMidday)
        guard case let .problem(message) = state else {
            Issue.record("expected \(specIdentifier) to render as a problem")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func plainPromptsUseTheirSpecCopyUnchanged() {
        #expect(presenter.displayState(for: "hello there", now: FixedDates.winterMidday)
            == .problem("Couldn't find a time — start with e.g. 14:30 or 2:30 pm"))
        #expect(presenter.displayState(for: "3pm in Tokyo", now: FixedDates.winterMidday)
            == .problem("Where is 3:00 pm? Add a zone before 'in'"))
    }

    /// No picker in this phase, so P4 has to say the candidates out loud.
    @Test func ambiguityPromptListsItsCandidatesInline() {
        #expect(presenter.displayState(for: "9am CST in London", now: FixedDates.winterMidday)
            == .problem("'cst' could mean more than one place — pick one: "
                + "Chicago (UTC-6), Shanghai (UTC+8)"))
    }

    @Test func ambiguityPromptListsAllSixUnitedStatesZones() throws {
        let state = presenter.displayState(for: "9am USA to London", now: FixedDates.winterMidday)
        guard case let .problem(message) = state else {
            Issue.record("expected a problem")
            return
        }
        for city in ["New York", "Chicago", "Denver", "Los Angeles", "Anchorage", "Honolulu"] {
            #expect(message.contains(city))
        }
    }

    // MARK: Launch argument

    @Test func launchArgumentPrefillIsReadFromUserDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "ConverterPresenterTests"))
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
        let defaults = try #require(UserDefaults(suiteName: "ConverterPresenterTests"))
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
            detailLine: "America/New_York → Europe/Lisbon"
        )))
    }
}
