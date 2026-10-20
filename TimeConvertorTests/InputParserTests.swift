import Testing
import Foundation
@testable import TimeConvertor

/// End-to-end parsing of the spec's example strings and the grammar rules
/// around them. The five prompt triggers live in `PromptTests`.
struct InputParserTests {
    private let parser = makeParser()

    // MARK: The spec's example strings

    /// "Examples that must parse" — all five tokenize into four grammar parts.
    @Test(arguments: [
        "12pm ET in London",
        "12 pm ET in London",
        "06:34 Portugal in PST",
        "23:15 UK to Porto",
        "9:30 am New York to Lisbon",
    ])
    func specExampleStringsTokenize(input: String) {
        guard case .tokens = InputTokenizer.tokenize(input) else {
            Issue.record("\(input) should tokenize")
            return
        }
    }

    @Test(arguments: [
        ("12pm ET in London", "America/New_York", "Europe/London", 12, 0),
        ("12 pm ET in London", "America/New_York", "Europe/London", 12, 0),
        ("23:15 UK to Porto", "Europe/London", "Europe/Lisbon", 23, 15),
        ("9:30 am New York to Lisbon", "America/New_York", "Europe/Lisbon", 9, 30),
        // Portugal resolves to its canonical national clock, not the Azores.
        ("06:34 Portugal in PST", "Europe/Lisbon", "America/Los_Angeles", 6, 34),
        // Single-digit 24-hour hour, H:mm.
        ("6:34 lisbon to pst", "Europe/Lisbon", "America/Los_Angeles", 6, 34),
    ])
    func specExampleStringsResolve(
        input: String,
        expectedSourceIdentifier: String,
        expectedTargetIdentifier: String,
        expectedHour: Int,
        expectedMinute: Int
    ) throws {
        let request = try #require(
            parser.parse(input, now: FixedDates.winterMidday).requestValue
        )
        #expect(request.sourceZone.timeZone.identifier == expectedSourceIdentifier)
        #expect(request.targetZone.timeZone.identifier == expectedTargetIdentifier)
        #expect(request.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
        #expect(request.referenceDate == FixedDates.winterMidday)
    }

    /// The echoed interpretation names the zone actually used, so the
    /// Lisbon-not-Azores choice is visible to the user.
    @Test func portugalExampleEchoesTheCanonicalZone() throws {
        let outcome = parser.parseAndConvert("06:34 Portugal in PST", now: FixedDates.winterMidday)
        let result = try #require(outcome.resultValue)
        #expect(result.summary == "6:34 am Lisbon (UTC+0) → 10:34 pm Los Angeles (UTC-8) -1d")
    }

    /// A redundant-but-consistent meridiem survives the whole pipeline: the
    /// zone token must not end up holding a stray `pm`.
    @Test(arguments: [
        ("13:00 pm et in london", 13, 0),
        ("18pm et in london", 18, 0),
        ("0:30 am et in london", 0, 30),
    ])
    func redundantMeridiemsConvertNormally(
        input: String,
        expectedHour: Int,
        expectedMinute: Int
    ) throws {
        let request = try #require(parser.parse(input, now: FixedDates.winterMidday).requestValue)
        #expect(request.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
        #expect(request.targetZone.timeZone.identifier == "Europe/London")
    }

    @Test func aRedundantMeridiemMatchesThePlainTwentyFourHourInput() throws {
        let withMeridiem = try #require(
            parser.parse("13:00 pm et in london", now: FixedDates.winterMidday).requestValue
        )
        let without = try #require(
            parser.parse("13:00 et in london", now: FixedDates.winterMidday).requestValue
        )
        #expect(withMeridiem == without)
    }

    /// H:mm and HH:mm are the same time; only the typing differs.
    @Test func singleDigitAndPaddedTwentyFourHourHoursAgree() throws {
        let padded = try #require(
            parser.parse("06:34 lisbon to pst", now: FixedDates.winterMidday).requestValue
        )
        let single = try #require(
            parser.parse("6:34 lisbon to pst", now: FixedDates.winterMidday).requestValue
        )
        #expect(padded == single)
    }

    /// Lenient spacing must not change the outcome at all.
    @Test(arguments: ["12pm et in london", "12 pm et in london",
                      "12:00pm et in london", "12:00 pm et in london"])
    func lenientSpacingVariantsProduceIdenticalRequests(input: String) throws {
        let request = try #require(parser.parse(input, now: FixedDates.winterMidday).requestValue)
        #expect(request.time == ParsedTime(hour: 12, minute: 0))
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
        #expect(request.targetZone.timeZone.identifier == "Europe/London")
    }

    @Test func caseIsIgnoredThroughout() throws {
        let upper = try #require(
            parser.parse("12PM ET IN LONDON", now: FixedDates.winterMidday).requestValue
        )
        let lower = try #require(
            parser.parse("12pm et in london", now: FixedDates.winterMidday).requestValue
        )
        #expect(upper == lower)
    }
}
