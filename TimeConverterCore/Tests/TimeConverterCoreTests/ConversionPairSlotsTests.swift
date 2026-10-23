import Testing
import Foundation
@testable import TimeConverterCore

/// The source side's own display slots — backlog item 20, phase A.
///
/// The iPad and Mac designs draw the source and target as two identical
/// columns, which is only possible if the source is decomposed the way the
/// target already was. These tests are the contract `ConversionPairView` draws
/// against: whatever the target gets, the source gets the same shape of.
///
/// Deliberately paired assertions throughout. The bug this guards against is
/// not "the source field is wrong" but "the source field was derived from the
/// target", which only shows up when the two are checked against each other.
struct ConversionPairSlotsTests {
    private let presenter = ConverterPresenter()

    private func display(for input: String, now: Date) throws -> ConverterDisplay {
        try #require(presenter.displayState(for: input, now: now).convertedDisplay)
    }

    // MARK: - The source clock splits like the target's

    /// The design's own example, both columns: `8:00 PM` → `4:00 PM`.
    @Test func bothSidesSplitIntoDigitsAndMeridiem() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.sourceClockDigits == "8:00")
        #expect(display.sourceMeridiem == "PM")
        #expect(display.targetClockDigits == "4:00")
        #expect(display.targetMeridiem == "PM")
    }

    /// Midnight and noon are where a naive digits/meridiem split goes wrong,
    /// and the source half needs the same proof the target half already has.
    @Test(arguments: [
        ("12am London to Tokyo", "12:00", "AM"),
        ("12pm London to Tokyo", "12:00", "PM"),
    ])
    func theSourceClockHandlesMidnightAndNoon(
        input: String,
        expectedDigits: String,
        expectedMeridiem: String
    ) throws {
        let display = try display(for: input, now: FixedDates.winterMidday)
        #expect(display.sourceClockDigits == expectedDigits)
        #expect(display.sourceMeridiem == expectedMeridiem)
    }

    /// The source clock is read off the **resolved instant**, not off the
    /// typed time — which is the whole reason it is a derived field rather
    /// than an echo of the input. On a spring-forward gap the two differ, and
    /// the column has to show where the clock actually landed.
    @Test func theSourceClockShowsTheResolvedTimeNotTheTypedOne() throws {
        let display = try display(
            for: "2:30 am ET in London",
            now: FixedDates.newYorkSpringForwardDay
        )
        #expect(display.sourceClockDigits == "3:00")
        #expect(display.sourceMeridiem == "AM")
        // And the gap is still explained rather than silently swallowed.
        #expect(display.daylightSavingNote
            == "2:30 am doesn't exist today in New York — clocks went forward")
    }

    // MARK: - Place names, without the preposition

    /// The pair's columns are captioned `FROM` and `TO`, so the names drop the
    /// `In` the iPhone's single column needs. Same content, two framings.
    @Test func placeNamesAreTheHeaderWithoutThePreposition() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.sourcePlaceName == "Lisbon")
        #expect(display.targetPlaceName == "Sao Paulo")
        #expect(display.targetPlaceLabel == "In Sao Paulo")
    }

    /// A typed abbreviation keeps the user's own word on both framings
    /// (item 21's rule), which means the pair's column says `ET (EASTERN
    /// TIME)` rather than throwing the code away.
    @Test func anAbbreviationKeepsItsCodeInThePlaceName() throws {
        let display = try display(for: "12pm ET in London", now: FixedDates.winterMidday)
        #expect(display.sourcePlaceName == "ET (Eastern Time)")
        #expect(display.targetPlaceName == "London")
    }

    /// A side the user never named stays marked as an assumption in the pair,
    /// exactly as it is in the iPhone's echo. An invisible default is the one
    /// bug this app cannot afford.
    @Test func aDefaultedSideKeepsItsLocalMarker() throws {
        let display = try #require(
            presenter.displayState(
                for: "7pm in London",
                now: FixedDates.winterMidday,
                localZone: FixedZones.losAngeles
            ).convertedDisplay
        )
        #expect(display.sourcePlaceName == "Los Angeles (local)")
        #expect(display.targetPlaceName == "London")
    }

    // MARK: - Item-21 sub-lines on both sides, no UTC anywhere

    /// Working assumption 1 of the sprint plan: the designs drew `UTC+1` and
    /// `UTC−3` under the two times, item 21 is newer, so both sub-lines name
    /// the zone instead — on every platform.
    @Test func bothSubLinesNameTheZoneRatherThanAnOffset() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.sourceZoneLine == "Western European Time (Lisbon)")
        #expect(display.targetZoneLine == "Brasilia Standard Time (São Paulo)")
        #expect(!display.sourceZoneLine.contains("UTC"))
        #expect(!display.targetZoneLine.contains("UTC"))
    }

    /// An abbreviation header has already named the zone, so its sub-line adds
    /// only the cities — the same two shapes item 21 gave the target.
    @Test func anAbbreviationSubLineIsJustItsCities() throws {
        let display = try display(for: "12pm ET in London", now: FixedDates.winterMidday)
        #expect(display.sourceZoneLine == "New York, Toronto")
    }

    /// The day rollover is a fact about where the **target** landed. Putting it
    /// on the source line too would claim the source moved day, which it did
    /// not.
    @Test func theRolloverRidesOnlyTheTargetSubLine() throws {
        let display = try display(for: "11pm new york to tokyo", now: FixedDates.winterMidday)
        #expect(display.targetZoneLine == "Japan Standard Time (Tokyo) · next day")
        #expect(display.sourceZoneLine == "Eastern Time (New York, Toronto)")
        #expect(!display.sourceZoneLine.contains("day"))
    }

    /// GMT and UTC have no cities by design, so their line is empty and the
    /// view draws nothing rather than a lone bracket — on the source side too.
    @Test func areferenceZoneSourceHasAnEmptySubLine() throws {
        let display = try display(for: "3pm UTC in London", now: FixedDates.winterMidday)
        #expect(display.sourceZoneLine.isEmpty)
    }

    // MARK: - The arrow phrase

    /// Page 4's labeled arrow: the footer's relationship with both names
    /// stripped, because the arrow it sits under is already pointing from one
    /// column to the other.
    @Test func theOffsetPhraseIsTheFooterWithoutItsNames() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.footerSentence == "Sao Paulo is 4 hours behind Lisbon.")
        #expect(display.offsetPhrase == "4 hours behind")
    }

    @Test func theOffsetPhraseAgreesWithTheSentenceInEveryDirection() throws {
        let ahead = try display(for: "9am new york to london", now: FixedDates.winterMidday)
        #expect(ahead.footerSentence == "London is 5 hours ahead of New York.")
        #expect(ahead.offsetPhrase == "5 hours ahead")

        let same = try display(for: "9am paris to madrid", now: FixedDates.winterMidday)
        #expect(same.footerSentence == "Madrid is the same time as Paris.")
        #expect(same.offsetPhrase == "Same time")
    }
}

/// The footer's re-wording, as the *display* delivers it — one suite, so the
/// surface the two shells actually render is pinned in one place.
struct FooterWordingTests {
    private let presenter = ConverterPresenter()

    /// The sentence names its subject now. This is the assertion to delete if
    /// Olivier answers open question 2 the other way.
    @Test(arguments: [
        ("8pm Lisbon in Sao Paulo", "Sao Paulo is 4 hours behind Lisbon."),
        ("9am new york to london", "London is 5 hours ahead of New York."),
        ("9am london to berlin", "Berlin is 1 hour ahead of London."),
        ("9am paris to madrid", "Madrid is the same time as Paris."),
        ("9am london to london", "Same time as London."),
    ])
    func theFooterNamesTheTarget(input: String, expected: String) throws {
        let display = try #require(
            presenter.displayState(for: input, now: FixedDates.summerMidday).convertedDisplay
        )
        #expect(display.footerSentence == expected)
    }

    /// Every footer is a complete sentence: a capital, a full stop, and no
    /// leading digit — the shape that broke when the subject was added in
    /// front of `4 hours behind`.
    @Test(arguments: [
        "8pm Lisbon in Sao Paulo",
        "9am new york to london",
        "12pm ET in London",
        "9am paris to madrid",
    ])
    func everyFooterIsAWholeSentence(input: String) throws {
        let display = try #require(
            presenter.displayState(for: input, now: FixedDates.summerMidday).convertedDisplay
        )
        let sentence = display.footerSentence
        #expect(sentence.hasSuffix("."))
        #expect(sentence.first?.isUppercase == true)
    }
}
