import Testing
import Foundation
@testable import TimeConvertor

/// The spec's DST-edge policy, exercised on real transition days with fixed
/// injected dates:
///
/// - a nonexistent local time resolves forward to the next valid instant;
/// - an ambiguous (repeated) local time takes the earlier instant;
/// - neither case prompts — the displayed UTC offsets make the choice visible.
struct DaylightSavingTransitionTests {
    private let engine = ConversionEngine()

    /// Clocks go forward in New York at 07:00 UTC on 2026-03-08: local 02:00
    /// becomes 03:00, so 02:30 never happens. The spec says resolve forward to
    /// the next valid instant — the transition itself.
    @Test func nonexistentLocalTimeResolvesForward() {
        let result = engine.convert(makeRequest(
            hour: 2,
            minute: 30,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.newYorkSpringForwardDay
        ))
        #expect(result.wallClockDisposition == .nonexistentTimeShiftedForward)
        #expect(result.instant == FixedDates.utc(year: 2026, month: 3, day: 8, hour: 7))
        // The echo shows the time actually used, and the offset makes the jump
        // visible: UTC-4, not UTC-5.
        #expect(result.source.formattedTime == "3:00 am")
        #expect(result.source.utcOffsetDescription == "UTC-4")
        #expect(result.requestedTime == ParsedTime(hour: 2, minute: 30))
        #expect(result.summary == "3:00 am New York (UTC-4) → 7:00 am London (UTC+0)")
    }

    /// The hour either side of the same gap is unaffected.
    @Test(arguments: [
        (1, 30, "UTC-5", 6, 30),
        (3, 30, "UTC-4", 7, 30),
    ])
    func timesEitherSideOfTheGapAreUnambiguous(
        hour: Int,
        minute: Int,
        expectedOffset: String,
        expectedUTCHour: Int,
        expectedUTCMinute: Int
    ) {
        let result = engine.convert(makeRequest(
            hour: hour,
            minute: minute,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.newYorkSpringForwardDay
        ))
        #expect(result.wallClockDisposition == .unambiguous)
        #expect(result.source.utcOffsetDescription == expectedOffset)
        #expect(result.instant == FixedDates.utc(
            year: 2026, month: 3, day: 8,
            hour: expectedUTCHour, minute: expectedUTCMinute
        ))
    }

    /// Clocks go back in New York at 06:00 UTC on 2026-11-01: local 01:30
    /// happens twice. The spec says take the earlier instant — the one still on
    /// daylight time, UTC-4.
    @Test func repeatedLocalTimeTakesTheEarlierInstant() {
        let result = engine.convert(makeRequest(
            hour: 1,
            minute: 30,
            from: "America/New_York",
            to: "Europe/London",
            now: FixedDates.newYorkFallBackDay
        ))
        #expect(result.wallClockDisposition == .repeatedTimeTookEarlier)
        #expect(result.instant == FixedDates.utc(
            year: 2026, month: 11, day: 1, hour: 5, minute: 30
        ))
        #expect(result.source.formattedTime == "1:30 am")
        #expect(result.source.utcOffsetDescription == "UTC-4")
    }

    /// The same policy in a different zone: UK clocks go forward at 01:00 UTC
    /// on 2026-03-29, so local 01:30 never happens in London.
    @Test func londonSpringForwardAlsoResolvesForward() {
        let result = engine.convert(makeRequest(
            hour: 1,
            minute: 30,
            from: "Europe/London",
            to: "America/New_York",
            now: FixedDates.londonSpringForwardDay
        ))
        #expect(result.wallClockDisposition == .nonexistentTimeShiftedForward)
        #expect(result.instant == FixedDates.utc(year: 2026, month: 3, day: 29, hour: 1))
        #expect(result.source.formattedTime == "2:00 am")
        #expect(result.source.utcOffsetDescription == "UTC+1")
    }

    /// A DST transition in the *target* zone needs no special handling — the
    /// instant is fixed by the source, the target just reads it.
    @Test func transitionInTheTargetZoneJustReadsTheInstant() {
        let result = engine.convert(makeRequest(
            hour: 12,
            from: "Asia/Tokyo",
            to: "America/New_York",
            now: FixedDates.newYorkSpringForwardDay
        ))
        #expect(result.wallClockDisposition == .unambiguous)
        #expect(result.target.utcOffsetDescription == "UTC-5")
        #expect(result.summary == "12:00 pm Tokyo (UTC+9) → 10:00 pm New York (UTC-5) -1d")
    }
}
