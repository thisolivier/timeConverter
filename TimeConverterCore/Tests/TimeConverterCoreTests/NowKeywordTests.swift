import Testing
import Foundation
@testable import TimeConverterCore

/// Item 23 — `now` as the leading time.
///
/// `now in Bangkok` is `<time> in <zone>` with the time being the injected
/// `now`, minutes included. It splits exactly like `7pm in Bangkok`, so the
/// source defaults to the device zone. `now` is input-only: it is matched as
/// the leading word, never as a zone, so `9am in now` is an unknown target.
struct NowKeywordTests {
    private let parser = makeParser()
    private let presenter = ConverterPresenter()

    private func outcome(
        for input: String,
        localZone: TimeZone = FixedZones.losAngeles
    ) -> ParseOutcome {
        parser.parse(input, now: FixedDates.winterAfternoonWithMinutes, localZone: localZone)
    }

    // MARK: Converts the current clock

    @Test func nowInAZoneConvertsTheCurrentLocalClock() throws {
        let request = try #require(outcome(for: "now in bangkok").requestValue)
        #expect(request.time == ParsedTime(hour: 15, minute: 42))
        #expect(request.sourceZone.isDeviceLocalZone)
        #expect(request.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(request.targetZone.timeZone.identifier == "Asia/Bangkok")
    }

    @Test(arguments: ["now in Bangkok", "NOW  in   bangkok", "now to bangkok", "  Now in bangkok "])
    func casingSpacingAndConjunctionDoNotMatter(input: String) throws {
        let request = try #require(outcome(for: input).requestValue)
        #expect(request.time == ParsedTime(hour: 15, minute: 42))
        #expect(request.targetZone.timeZone.identifier == "Asia/Bangkok")
    }

    @Test func theRenderedEchoCarriesTheLocalMarkerAndMinutes() {
        let echoLine = presenter.displayState(
            for: "now in bangkok",
            now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        ).convertedDisplay?.echoLine
        #expect(echoLine?.hasPrefix("3:42 pm Los Angeles (local, UTC-8) → 6:42 am") == true)
    }

    /// A named source reads *its* clock, so the instant stays the real present:
    /// 23:42 UTC is 18:42 in New York, and the converted instant is `now`.
    @Test func aNamedSourceReadsThatZonesClock() throws {
        let request = try #require(outcome(for: "now ET in london").requestValue)
        #expect(request.time == ParsedTime(hour: 18, minute: 42))
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
        let result = ConversionEngine().convert(request)
        #expect(result.instant == FixedDates.winterAfternoonWithMinutes)
    }

    // MARK: Missing zone, and now-is-not-a-zone

    @Test(arguments: ["now", "now in", "now to"])
    func nowWithNoZoneIsP2(input: String) {
        #expect(outcome(for: input).promptValue == .zoneNotFound(time: nil))
    }

    @Test func theP2MessageSaysNow() {
        #expect(Prompt.zoneNotFound(time: nil).message.hasPrefix("Convert now where?"))
    }

    @Test(arguments: ["9am in now", "now in now"])
    func nowIsNeverADestination(input: String) {
        guard case let .unknownZone(token, side, _) = outcome(for: input).promptValue else {
            Issue.record("expected P5 for \(input)")
            return
        }
        #expect(token == "now")
        #expect(side == .target)
    }

    /// Only a standalone leading word counts: a zone that merely starts with
    /// the letters stays a bare-zone input.
    @Test func aWordStartingWithNowIsNotTheKeyword() throws {
        guard case let .unknownZone(token, _, _) = outcome(for: "nowhere").promptValue else {
            Issue.record("expected P5 for nowhere")
            return
        }
        #expect(token == "nowhere")
    }
}
