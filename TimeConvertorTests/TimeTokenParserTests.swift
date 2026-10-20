import Testing
import Foundation
@testable import TimeConvertor

/// The `<time>` half of the grammar, including the spec's lenient-spacing rule
/// and the 12 am / 12 pm convention.
struct TimeTokenParserTests {
    // MARK: 24-hour form

    @Test(arguments: [
        ("06:34", 6, 34),
        ("6:34", 6, 34),
        ("00:00", 0, 0),
        ("23:15", 23, 15),
        ("23:59", 23, 59),
    ])
    func twentyFourHourTimesParse(input: String, expectedHour: Int, expectedMinute: Int) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
        #expect(match.remainder.isEmpty)
    }

    // MARK: 12-hour form and lenient spacing

    /// All four spellings the spec calls out must land on the same time.
    @Test(arguments: ["12pm", "12 pm", "12:00pm", "12:00 pm"])
    func lenientSpacingVariantsAgree(input: String) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: 12, minute: 0))
    }

    @Test(arguments: ["12:30pm", "12:30 pm"])
    func lenientSpacingWithMinutes(input: String) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: 12, minute: 30))
    }

    /// The midnight/noon convention: 12 am is the start of the day, 12 pm noon.
    @Test func twelveAmIsMidnightAndTwelvePmIsNoon() throws {
        let midnight = try #require(TimeTokenParser.match(atStartOf: "12 am"))
        #expect(midnight.time == ParsedTime(hour: 0, minute: 0))
        #expect(midnight.time.canonicalDescription == "12:00 am")

        let noon = try #require(TimeTokenParser.match(atStartOf: "12 pm"))
        #expect(noon.time == ParsedTime(hour: 12, minute: 0))
        #expect(noon.time.canonicalDescription == "12:00 pm")
    }

    @Test(arguments: [
        ("1am", 1, 0),
        ("1 am", 1, 0),
        ("11:45pm", 23, 45),
        ("9:30 am", 9, 30),
    ])
    func twelveHourTimesParse(input: String, expectedHour: Int, expectedMinute: Int) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
    }

    // MARK: Redundant meridiems

    /// A meridiem that merely agrees with an out-of-12-hour-range hour is
    /// accepted and means the 24-hour time it already named.
    @Test(arguments: [
        ("13:00 pm", 13, 0),
        ("13:00pm", 13, 0),
        ("18pm", 18, 0),
        ("23:59 pm", 23, 59),
        ("0:30 am", 0, 30),
        ("0am", 0, 0),
    ])
    func redundantButConsistentMeridiemsAreAccepted(
        input: String,
        expectedHour: Int,
        expectedMinute: Int
    ) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
    }

    /// A meridiem that contradicts its hour fails outright. It must *not* fall
    /// through to the 24-hour pattern, which would parse the time and quietly
    /// push the stray `am`/`pm` into the zone token.
    @Test(arguments: ["13:00 am", "13am", "18 am", "23:59 am", "0:30 pm", "0 pm"])
    func contradictoryMeridiemsAreRejected(input: String) {
        #expect(TimeTokenParser.match(atStartOf: input) == nil)
        #expect(TimeTokenParser.match(atStartOf: "\(input) et in london") == nil)
    }

    /// Hours 1–12 keep the ordinary 12-hour meaning either way.
    @Test(arguments: [
        ("11 am", 11, 0),
        ("11 pm", 23, 0),
        ("1 am", 1, 0),
        ("1 pm", 13, 0),
    ])
    func hoursWithinTheClockFaceAreUnaffected(
        input: String,
        expectedHour: Int,
        expectedMinute: Int
    ) throws {
        let match = try #require(TimeTokenParser.match(atStartOf: input))
        #expect(match.time == ParsedTime(hour: expectedHour, minute: expectedMinute))
    }

    /// `13:00 pm` and `13:00` are the same time, typed differently.
    @Test func aRedundantMeridiemAgreesWithThePlainTwentyFourHourForm() throws {
        let withMeridiem = try #require(TimeTokenParser.match(atStartOf: "13:00 pm"))
        let without = try #require(TimeTokenParser.match(atStartOf: "13:00"))
        #expect(withMeridiem.time == without.time)
    }

    // MARK: Precedence

    /// `9:30 am ...` must not be read as the 24-hour `9:30` followed by a zone
    /// token beginning with "am".
    @Test func twelveHourFormWinsOverTwentyFourHourForm() throws {
        let match = try #require(TimeTokenParser.match(atStartOf: "9:30 am new york to lisbon"))
        #expect(match.time == ParsedTime(hour: 9, minute: 30))
        #expect(match.remainder == "new york to lisbon")
    }

    @Test func remainderDropsTheTimeAndLeadingSpace() throws {
        let match = try #require(TimeTokenParser.match(atStartOf: "12pm et in london"))
        #expect(match.remainder == "et in london")
    }

    // MARK: Rejections

    @Test(arguments: [
        "",                 // nothing at all
        "hello there",      // no digits
        "6 et in london",   // bare hour: 24-hour form needs minutes
        "25:00 et",         // hour out of range
        "25:00 pm et",      // out of range with a meridiem too
        "06:60 et",         // minute out of range
        "13:00 am et",      // meridiem contradicts the hour
        "0 pm et",          // ditto
        "12pmet in london", // meridiem must end on a word boundary
        "et in london",     // zone first, no time
    ])
    func unparseableTimesAreRejected(input: String) {
        #expect(TimeTokenParser.match(atStartOf: input) == nil)
    }

    // MARK: Canonical echo

    @Test(arguments: [
        (0, 0, "12:00 am"),
        (0, 5, "12:05 am"),
        (9, 30, "9:30 am"),
        (12, 0, "12:00 pm"),
        (17, 0, "5:00 pm"),
        (23, 15, "11:15 pm"),
    ])
    func canonicalDescriptionAlwaysUsesTwelveHourWithASpace(
        hour: Int,
        minute: Int,
        expected: String
    ) {
        #expect(ParsedTime(hour: hour, minute: minute).canonicalDescription == expected)
    }
}
