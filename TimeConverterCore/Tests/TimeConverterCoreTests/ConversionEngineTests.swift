import Testing
import Foundation
@testable import TimeConverterCore

/// Conversion, echo formatting and day rollover. The DST-edge policy has its
/// own suite in `DaylightSavingTransitionTests`.
///
/// Every test injects a date from `FixedDates`; nothing here calls `Date()`.
struct ConversionEngineTests {
    private let engine = ConversionEngine()

    // MARK: The spec's output example

    @Test func specOutputExampleIsReproducedExactly() {
        let result = engine.convert(makeRequest(
            hour: 12,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.winterMidday
        ))
        #expect(result.summary == "12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0)")
        #expect(result.dayRolloverMarker == nil)
    }

    /// Same input, six months later: the offsets follow DST without any extra
    /// work, because the zones are IANA zones rather than fixed offsets.
    @Test func offsetsFollowTheSeasonOfTheInjectedDate() {
        let result = engine.convert(makeRequest(
            hour: 12,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.summerMidday
        ))
        #expect(result.summary == "12:00 pm New York (UTC-4) → 5:00 pm London (UTC+1)")
    }

    @Test func halfHourOffsetsRenderWithMinutes() {
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "Asia/Kolkata",
            to: "Europe/London",
            now: FixedDates.winterMidday
        ))
        #expect(result.source.utcOffsetDescription == "UTC+5:30")
        #expect(result.summary == "9:00 am Kolkata (UTC+5:30) → 3:30 am London (UTC+0)")
    }

    // MARK: Day rollover

    @Test func forwardRolloverIsMarked() {
        let result = engine.convert(makeRequest(
            hour: 23,
            from: "America/New_York",
            to: "Asia/Tokyo",
            now: FixedDates.winterMidday
        ))
        #expect(result.dayOffset == 1)
        #expect(result.dayRolloverMarker == "+1d")
        #expect(result.summary == "11:00 pm New York (UTC-5) → 1:00 pm Tokyo (UTC+9) +1d")
    }

    @Test func backwardRolloverIsMarked() {
        let result = engine.convert(makeRequest(
            hour: 1,
            from: "Asia/Tokyo",
            to: "America/New_York",
            now: FixedDates.winterMidday
        ))
        #expect(result.dayOffset == -1)
        #expect(result.dayRolloverMarker == "-1d")
        #expect(result.summary == "1:00 am Tokyo (UTC+9) → 11:00 am New York (UTC-5) -1d")
    }

    @Test func sameDayConversionHasNoMarker() {
        let result = engine.convert(makeRequest(
            hour: 9,
            minute: 30,
            from: "America/New_York",
            to: "Europe/Lisbon",
            now: FixedDates.winterMidday
        ))
        #expect(result.dayOffset == 0)
        #expect(result.dayRolloverMarker == nil)
    }

    /// Rollover must survive a month boundary — the comparison is on absolute
    /// day numbers, not day-of-month.
    @Test func rolloverWorksAcrossAMonthBoundary() {
        let result = engine.convert(makeRequest(
            hour: 23,
            from: "America/New_York",
            to: "Asia/Tokyo",
            now: FixedDates.utc(year: 2026, month: 1, day: 31, hour: 18)
        ))
        #expect(result.dayOffset == 1)
    }

    // MARK: "Today" is read in the source zone

    /// The reference instant is 02:00 UTC on 15 January, which in New York is
    /// still the 14th. The conversion must use New York's today, not the
    /// caller's.
    @Test func todayIsTheSourceZonesToday() {
        let justAfterUTCMidnight = FixedDates.utc(year: 2026, month: 1, day: 15, hour: 2)
        let result = engine.convert(makeRequest(
            hour: 9,
            from: "America/New_York",
            to: "Europe/London",
            now: justAfterUTCMidnight
        ))
        // 09:00 on 14 January in New York (UTC-5) is 14:00 UTC the same day.
        #expect(result.instant == FixedDates.utc(year: 2026, month: 1, day: 14, hour: 14))
    }

    // MARK: End to end through the parser

    /// `ET` is an abbreviation, so the echo expands it (item 13); `London` is a
    /// city token and is untouched.
    @Test func parseAndConvertComposesBothSteps() throws {
        let outcome = makeParser().parseAndConvert("12pm ET in London", now: FixedDates.winterMidday)
        let result = try #require(outcome.resultValue)
        #expect(result.summary == "12:00 pm Eastern Time (New York, Toronto, UTC-5) "
            + "→ 5:00 pm London (UTC+0)")
    }

    @Test func parseAndConvertPassesPromptsStraightThrough() throws {
        let outcome = makeParser().parseAndConvert("hello", now: FixedDates.winterMidday)
        #expect(outcome.promptValue?.specIdentifier == "P1")
        #expect(outcome.resultValue == nil)
    }
}
