import Testing
import Foundation
@testable import TimeConverter

/// One suite per spec requirement: each prompt the spec still defines, its
/// trigger, and the copy the prompt table specifies. P3 was retired on
/// 2026-10-22; what used to trigger it is covered here as the conversions it
/// became, and in `LocalZoneDefaultingTests`.
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

    // MARK: P2 — no zone anywhere

    /// Reworded by the 2026-10-22 amendment: a time with no zone at all is the
    /// *only* missing-zone case left, so the copy no longer asks for the source
    /// side specifically.
    @Test func timeAloneTriggersP2() throws {
        let prompt = try #require(parser.parse("3pm", now: FixedDates.winterMidday).promptValue)
        #expect(prompt == .zoneNotFound(time: ParsedTime(hour: 15, minute: 0)))
        #expect(prompt.specIdentifier == "P2")
        #expect(prompt.message == "Convert 3:00 pm where? Add a timezone, city, or country")
    }

    /// A conjunction with nothing on either side of it names no zone either, so
    /// it renders P2 rather than the retired P3.
    @Test(arguments: ["3pm in", "3pm to", "3pm in "])
    func aDanglingConjunctionWithNoZoneAtAllTriggersP2(input: String) throws {
        let prompt = try #require(parser.parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt == .zoneNotFound(time: ParsedTime(hour: 15, minute: 0)))
        #expect(prompt.message == "Convert 3:00 pm where? Add a timezone, city, or country")
    }

    /// Migrated from `missingSourceZoneTriggersP2`. The spec's old rejection
    /// example is now a conversion: the conjunction makes Tokyo the target and
    /// the source defaults to the injected device zone.
    @Test func aLoneTargetZoneNoLongerPromptsAtAll() throws {
        let outcome = parser.parse(
            "3pm in Tokyo", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        let request = try #require(outcome.requestValue)
        #expect(request.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(request.sourceZone.isDeviceLocalZone)
        #expect(request.targetZone.timeZone.identifier == "Asia/Tokyo")
    }

    // MARK: P3 — retired 2026-10-22

    /// Migrated from `noConjunctionTriggersP3`. The spec's other rejection
    /// example converts too, the other way round: with no conjunction, Portugal
    /// is the source and the *target* defaults to local.
    @Test func aLoneSourceZoneNoLongerPromptsEither() throws {
        let outcome = parser.parse(
            "06:34 Portugal", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        let request = try #require(outcome.requestValue)
        #expect(request.sourceZone.timeZone.identifier == "Europe/Lisbon")
        #expect(request.targetZone.timeZone == FixedZones.losAngeles)
        #expect(request.targetZone.isDeviceLocalZone)
    }

    /// Migrated from `conjunctionWithNothingAfterItTriggersP3`. A named zone
    /// *before* a dangling conjunction is still a named source — the
    /// conjunction's job is only to say which side the named zone is on — so
    /// this converts rather than prompting. P2 is reserved for inputs naming no
    /// zone at all.
    @Test func aNamedZoneBeforeADanglingConjunctionStillConverts() throws {
        let outcome = parser.parse(
            "3pm tokyo in", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        let request = try #require(outcome.requestValue)
        #expect(request.sourceZone.timeZone.identifier == "Asia/Tokyo")
        #expect(request.targetZone.isDeviceLocalZone)
    }

    /// No prompt reports P3 any more, whatever the input.
    @Test(arguments: [
        "hello there", "3pm", "3pm in", "06:34 Portugal", "3pm in Tokyo",
        "9am CST in London", "9am Narnia in London",
    ])
    func noInputCanProduceP3(input: String) {
        let prompt = makeParser().parse(input, now: FixedDates.winterMidday).promptValue
        #expect(prompt?.specIdentifier != "P3")
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
