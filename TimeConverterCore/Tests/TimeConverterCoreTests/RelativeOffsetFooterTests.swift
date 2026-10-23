import Testing
import Foundation
@testable import TimeConverterCore

/// The footer sentence — spec amendment 2026-10-23, the one functional
/// addition of the design sprint (backlog item 18).
///
/// Two layers, deliberately: the arithmetic-free string formatting is tested
/// against raw second counts, so the grammar cases (singular, decimals,
/// same-offset) are exhaustive and don't depend on any city still having the
/// offset the test assumed; then the engine is tested end to end against real
/// zones, which is what proves the difference is taken **at the resolved
/// instant** rather than from a standard offset.
struct RelativeOffsetSentenceFormattingTests {
    @Test func aheadAndBehindAreTheTargetRelativeToTheSource() {
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: -4 * 3600, sourcePlaceName: "Lisbon"
        ) == "4 hours behind Lisbon.")
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: 3 * 3600, sourcePlaceName: "New York"
        ) == "3 hours ahead of New York.")
    }

    /// No offset difference gets its own sentence rather than "0 hours ahead",
    /// which is what the spec's third example is for.
    @Test func noDifferenceReadsAsSameTime() {
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: 0, sourcePlaceName: "London"
        ) == "Same time as London.")
    }

    @Test func oneHourIsSingularInBothDirections() {
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: 3600, sourcePlaceName: "London"
        ) == "1 hour ahead of London.")
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: -3600, sourcePlaceName: "London"
        ) == "1 hour behind London.")
    }

    /// Quarter, half and three-quarter zones all exist, so all three decimal
    /// shapes have to read properly — and a half hour is `4.5`, never `4.50`.
    @Test(arguments: [
        (15 * 60, "0.25 hours"),
        (30 * 60, "0.5 hours"),
        (45 * 60, "0.75 hours"),
        (3600 + 30 * 60, "1.5 hours"),
        (4 * 3600 + 30 * 60, "4.5 hours"),
        (5 * 3600 + 45 * 60, "5.75 hours"),
        (12 * 3600 + 45 * 60, "12.75 hours"),
    ])
    func fractionalHoursRenderDecimally(seconds: Int, expected: String) {
        #expect(RelativeOffsetFormatting.hourCountDescription(seconds: seconds) == expected)
    }

    /// A fractional count is plural even below one hour: "0.5 hour" is not
    /// English.
    @Test func fractionalCountsStayPlural() {
        #expect(RelativeOffsetFormatting.sentence(
            differenceInSeconds: 30 * 60, sourcePlaceName: "Kathmandu"
        ) == "0.5 hours ahead of Kathmandu.")
    }

    /// The decimal separator is a period on every device. A locale-driven
    /// formatter would print `4,5 hours` in Lisbon, which is the bug this
    /// hand-rolled formatting exists to prevent.
    @Test func theDecimalSeparatorIsNotLocaleDependent() {
        #expect(RelativeOffsetFormatting.hourCountDescription(seconds: 4 * 3600 + 30 * 60)
            .contains("."))
        #expect(!RelativeOffsetFormatting.hourCountDescription(seconds: 4 * 3600 + 30 * 60)
            .contains(","))
    }
}

/// The footer as the engine actually produces it, from real zones.
struct RelativeOffsetFooterEngineTests {
    private let engine = ConversionEngine()

    /// The design's own example: Lisbon in July is UTC+1 and São Paulo is
    /// UTC-3, so the mockup's footer is reproduced exactly.
    @Test func theDesignsFooterIsReproducedExactly() {
        let result = engine.convert(makeRequest(
            hour: 20,
            from: "Europe/Lisbon",
            to: "America/Sao_Paulo",
            now: FixedDates.summerMidday
        ))
        #expect(result.relativeOffsetSentence == "4 hours behind Lisbon.")
    }

    @Test func anEasterlyTargetIsAheadOfTheSource() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "5 hours ahead of New York.")
    }

    /// A half-hour zone, which is the case a whole-hour implementation gets
    /// silently wrong: India is UTC+5:30, so the gap to London is 5.5 hours and
    /// not 5 or 6.
    @Test func aHalfHourZoneReadsDecimally() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/London",
            to: "Asia/Kolkata",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "5.5 hours ahead of London.")
    }

    @Test func aHalfHourZoneIsAlsoRightInTheOtherDirection() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Asia/Kolkata",
            to: "Europe/London",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "5.5 hours behind Kolkata.")
    }

    /// Nepal is UTC+5:45 — the three-quarter case, in the wild.
    @Test func aThreeQuarterHourZoneReadsDecimally() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/London",
            to: "Asia/Kathmandu",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "5.75 hours ahead of London.")
    }

    /// Two different places sharing an offset: the sentence says so rather than
    /// claiming a zero-hour difference.
    @Test func aSameOffsetPairReadsAsSameTime() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/Paris",
            to: "Europe/Madrid",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "Same time as Paris.")
    }

    /// The same zone on both sides is the degenerate version of the above.
    @Test func oneZoneToItselfReadsAsSameTime() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/London",
            to: "Europe/London",
            now: FixedDates.winterMidday
        ))
        #expect(result.relativeOffsetSentence == "Same time as London.")
    }

    /// The whole reason the difference is taken at the resolved instant: for a
    /// few weeks each spring the US has changed its clocks and Europe has not,
    /// so London–New York is 4 hours rather than its usual 5. A standard-offset
    /// implementation would say 5 and be wrong for the day the user asked
    /// about.
    @Test func theDifferenceFollowsDaylightSavingOnTheDayAsked() {
        let inTheMismatchedWeeks = FixedDates.utc(year: 2026, month: 3, day: 20)
        let mismatched = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/London",
            to: "America/New_York",
            now: inTheMismatchedWeeks
        ))
        #expect(mismatched.relativeOffsetSentence == "4 hours behind London.")

        let ordinary = engine.convert(makeRequest(
            hour: 9,
            from: "Europe/London",
            to: "America/New_York",
            now: FixedDates.winterMidday
        ))
        #expect(ordinary.relativeOffsetSentence == "5 hours behind London.")
    }

    /// An abbreviation-resolved source is named by its display name, which is
    /// what the spec amendment says the sentence uses — the same name the box
    /// echo above it shows, so the two lines agree.
    @Test func anAbbreviationSourceIsNamedByItsDisplayName() throws {
        let outcome = makeParser().parseAndConvert(
            "12pm ET in London",
            now: FixedDates.winterMidday
        )
        let result = try #require(outcome.resultValue)
        #expect(result.relativeOffsetSentence == "5 hours ahead of Eastern Time.")
    }

    /// A side the user never named still has a name in the footer: the
    /// defaulted device zone's city.
    @Test func aDefaultedSourceIsNamedByItsCity() throws {
        let outcome = makeParser().parseAndConvert(
            "7pm in London",
            now: FixedDates.winterMidday,
            localZone: FixedZones.losAngeles
        )
        let result = try #require(outcome.resultValue)
        #expect(result.relativeOffsetSentence == "8 hours ahead of Los Angeles.")
    }
}
