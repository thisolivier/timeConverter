import Testing
import Foundation
@testable import TimeConverter

/// One suite per spec requirement: each of the five prompts, its trigger, and
/// the copy the spec's prompt table specifies.
struct PromptTests {
    private let parser = makeParser()

    // MARK: P1 — no parseable time

    @Test(arguments: [
        "", "   ", "hello there", "london to paris",
        "6 et in london",       // 24-hour form needs minutes
        "13:00 am et in london", // meridiem contradicts the hour
        "0:30 pm et in london",  // ditto
    ])
    func missingTimeTriggersP1(input: String) throws {
        let prompt = try #require(parser.parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P1")
        #expect(prompt.message == "Couldn't find a time — start with e.g. 14:30 or 2:30 pm")
    }

    // MARK: P2 — missing source zone

    /// The spec's own rejection example: a lone target zone never silently
    /// assumes the device's zone for the source.
    @Test func missingSourceZoneTriggersP2() throws {
        let prompt = try #require(
            parser.parse("3pm in Tokyo", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt == .missingSourceZone(
            time: ParsedTime(hour: 15, minute: 0),
            conjunction: .inWord
        ))
        #expect(prompt.message == "Where is 3:00 pm? Add a zone before 'in'")
    }

    /// Nothing after the time at all: still the source zone that's missing
    /// first, but there's no conjunction to quote yet.
    @Test func timeAloneTriggersP2WithNoConjunction() throws {
        let prompt = try #require(parser.parse("3pm", now: FixedDates.winterMidday).promptValue)
        #expect(prompt == .missingSourceZone(
            time: ParsedTime(hour: 15, minute: 0),
            conjunction: nil
        ))
        #expect(prompt.message == "Where is 3:00 pm? Add a zone before 'in' or 'to'")
    }

    // MARK: P3 — missing target zone

    /// The spec's other rejection example.
    @Test func noConjunctionTriggersP3() throws {
        let prompt = try #require(
            parser.parse("06:34 Portugal", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt == .missingTargetZone(
            time: ParsedTime(hour: 6, minute: 34),
            sourceZoneToken: "portugal"
        ))
        #expect(prompt.message
            == "Convert 6:34 am portugal to where? Add 'in' or 'to' + a place")
    }

    @Test func conjunctionWithNothingAfterItTriggersP3() throws {
        let prompt = try #require(
            parser.parse("3pm tokyo in", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.specIdentifier == "P3")
        #expect(prompt.offendingToken == "tokyo")
    }

    // MARK: P4 — ambiguous zone

    @Test func cstPromptsWithBothMeaningsAndTheirOffsets() throws {
        let prompt = try #require(
            parser.parse("9am CST in London", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == .source)
        #expect(prompt.ambiguousChoices == [
            ZoneChoice(
                timeZoneIdentifier: "America/Chicago",
                representativeCity: "Chicago",
                utcOffsetDescription: "UTC-6"
            ),
            ZoneChoice(
                timeZoneIdentifier: "Asia/Shanghai",
                representativeCity: "Shanghai",
                utcOffsetDescription: "UTC+8"
            ),
        ])
    }

    @Test func istPromptsWithBothMeaningsAndTheirOffsets() throws {
        let prompt = try #require(
            parser.parse("9am IST in London", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.ambiguousChoices == [
            ZoneChoice(
                timeZoneIdentifier: "Asia/Kolkata",
                representativeCity: "Kolkata",
                utcOffsetDescription: "UTC+5:30"
            ),
            ZoneChoice(
                timeZoneIdentifier: "Europe/Dublin",
                representativeCity: "Dublin",
                utcOffsetDescription: "UTC+0"
            ),
        ])
    }

    /// Offsets in the picker are computed at the injected date, so they follow
    /// the season.
    @Test func pickerOffsetsFollowTheInjectedDate() throws {
        let summerPrompt = try #require(
            parser.parse("9am IST in London", now: FixedDates.summerMidday).promptValue
        )
        let dublinChoice = try #require(
            summerPrompt.ambiguousChoices?.first { $0.timeZoneIdentifier == "Europe/Dublin" }
        )
        #expect(dublinChoice.utcOffsetDescription == "UTC+1")
    }

    /// A country with no national clock still prompts.
    @Test func usaPromptsWithTheSixPrimaryZones() throws {
        let prompt = try #require(
            parser.parse("9am USA to London", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == .source)
        #expect(prompt.offendingToken == "usa")
        #expect(prompt.ambiguousChoices?.map(\.representativeCity) == [
            "New York", "Chicago", "Denver", "Los Angeles", "Anchorage", "Honolulu",
        ])
        #expect(prompt.ambiguousChoices?.map(\.utcOffsetDescription) == [
            "UTC-5", "UTC-6", "UTC-7", "UTC-8", "UTC-9", "UTC-10",
        ])
    }

    @Test func ambiguousTargetZoneIsReportedAgainstTheTargetSide() throws {
        let prompt = try #require(
            parser.parse("9am London in Australia", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == .target)
        #expect(prompt.offendingToken == "australia")
    }

    // MARK: P5 — unknown zone

    @Test func unknownSourceZoneTriggersP5() throws {
        let input = "9am Narnia in London"
        let prompt = try #require(parser.parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt == .unknownZone(
            token: "narnia",
            side: .source,
            tokenRange: rawRange(of: "Narnia", in: input)
        ))
        #expect(prompt.message == "Don't recognize 'narnia' — try a timezone (ET, PST), "
            + "a major city, or a country")
    }

    @Test func unknownTargetZoneTriggersP5() throws {
        let input = "9am London in Narnia"
        let prompt = try #require(parser.parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt == .unknownZone(
            token: "narnia",
            side: .target,
            tokenRange: rawRange(of: "Narnia", in: input)
        ))
    }

    /// Two bad tokens: the user is asked about the left-hand one first.
    @Test func zonesAreResolvedLeftToRight() throws {
        let prompt = try #require(
            parser.parse("9am Narnia in Atlantis", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.side == .source)
        #expect(prompt.offendingToken == "narnia")
    }
}
