import Testing
import Foundation
@testable import TimeConverterCore

/// Item 27 — compact 24-hour times (spec amended 2026-10-28).
///
/// `HHmm` / `Hmm` is `HH:mm` with the colon left out: the last two digits are
/// always the minutes, so `930` is 9:30. A meridiem may follow (`600pm`) under
/// the existing redundant/contradictory rule. Two digits stay P1 (item 23), and
/// the time must end on a word boundary, so `1500m` and `15000` never match.
struct CompactTimeTests {
    private let parser = makeParser()

    // MARK: Parsing

    @Test(arguments: [
        ("1500", 15, 0),
        ("0600", 6, 0),
        ("600", 6, 0),
        ("930", 9, 30),
        ("130", 1, 30),
        ("0000", 0, 0),
        ("000", 0, 0),
        ("2359", 23, 59),
        ("1234", 12, 34),
    ])
    func compactTwentyFourHourTimesParse(input: String, expectedHour: Int, expectedMinute: Int) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
        #expect(match.remainder.isEmpty)
    }

    /// The compact form and the colon form are the same time, typed differently.
    @Test(arguments: [("1500", "15:00"), ("0630", "06:30"), ("930", "9:30")])
    func compactAndColonFormsAgree(compact: String, withColon: String) throws {
        let compactMatch = try #require(TimeTokenParser.match(atStartOf: compact))
        let colonMatch = try #require(TimeTokenParser.match(atStartOf: withColon))
        #expect(compactMatch.time == colonMatch.time)
    }

    @Test(arguments: [
        ("600pm", 18, 0),
        ("600 pm", 18, 0),
        ("930am", 9, 30),
        ("1230am", 0, 30),
        ("1230 pm", 12, 30),
        ("1300pm", 13, 0),   // redundant but agreeing
        ("100pm", 13, 0),
    ])
    func compactTimesTakeAnOptionalMeridiem(input: String, expectedHour: Int, expectedMinute: Int) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
    }

    @Test(arguments: [
        "2400",          // hour out of range
        "1260",          // minute out of range
        "960",           // three digits are H + mm, and 60 is not a minute
        "093",           // likewise: 0 + 93
        "15000",         // five digits never match
        "1500m",         // glued to a letter
        "1500et",
        "1300am",        // contradicting meridiem, and no 24-hour retry
        "12",            // two digits: item 23's decision stands
        "1500:00",
    ])
    func malformedCompactTimesAreRejected(input: String) {
        #expect(TimeTokenParser.match(atStartOf: input) == nil)
        #expect(TimeTokenParser.match(atStartOf: "\(input) et in london") == nil)
    }

    // MARK: End to end

    @Test func acompactTimeConvertsLikeItsColonForm() throws {
        let compact = try #require(parser.parseAndConvert("1500 ET in London", now: FixedDates.winterMidday).resultValue)
        let colon = try #require(parser.parseAndConvert("15:00 ET in London", now: FixedDates.winterMidday).resultValue)
        #expect(compact.summary == colon.summary)
        #expect(compact.summary == "3:00 pm Eastern Time (New York, Toronto, UTC-5) → 8:00 pm London (UTC+0)")
    }

    @Test func thezoneTokenStartsAfterTheCompactTime() throws {
        let tokens = InputTokenizer.tokenize("0600 Tokyo to Paris")
        guard case let .tokens(parts) = tokens else {
            Issue.record("expected tokens, got \(tokens)")
            return
        }
        #expect(parts.time == ParsedTime(hour: 6, minute: 0))
        #expect(parts.sourceZoneToken == "tokyo")
        #expect(parts.sourceZone?.rawRange == rawRange(of: "Tokyo", in: "0600 Tokyo to Paris"))
        #expect(parts.targetZoneToken == "paris")
    }

    /// A lone 4-digit number used to be P1; it is now a time with no zone.
    @Test func alone4DigitTimeIsP2NotP1() throws {
        let prompt = try #require(parser.parse("1234", now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P2")
    }

    /// Glued letters are not a zone: the whole thing is P1, as `12pmet` is.
    @Test(arguments: ["1500m", "1500et in london", "15000 et in london"])
    func gluedOrOverlongDigitsAreP1(input: String) throws {
        let prompt = try #require(parser.parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P1")
    }
}
