import Testing
import Foundation
@testable import TimeConverterCore

/// Item 22 — bare-zone input converts the current clock (spec amended
/// 2026-10-23).
///
/// `ET` on its own means "what is the time in ET right now": the time is the
/// injected `now` read in the injected device zone, **minutes included**, the
/// source is that device zone (so the echo carries item 14's `(local)` marker)
/// and the target is the named token, resolved through the ordinary chain — P4
/// and P5 included, chips and all.
///
/// Nothing here reads `TimeZone.current` or `Date()`: both arrive as
/// parameters, which is why the echo strings below can be exact.
struct BareZoneInputTests {
    private let parser = makeParser()
    private let presenter = ConverterPresenter()

    private func echoLine(
        for input: String,
        localZone: TimeZone = FixedZones.losAngeles,
        now: Date = FixedDates.winterAfternoonWithMinutes
    ) -> String? {
        presenter.displayState(for: input, now: now, localZone: localZone)
            .convertedDisplay?.echoLine
    }

    private func request(
        for input: String,
        localZone: TimeZone = FixedZones.losAngeles,
        now: Date = FixedDates.winterAfternoonWithMinutes
    ) -> ConversionRequest? {
        parser.parse(input, now: now, localZone: localZone).requestValue
    }

    // MARK: The four token shapes all convert

    /// An alias, a tz-database city, a country and a multi-word alias: every
    /// shape of zone token the chain can resolve works bare, because the bare
    /// case is just "the target side, with no time typed".
    @Test(arguments: [
        ("ET", "America/New_York"),
        ("Tokyo", "Asia/Tokyo"),
        ("japan", "Asia/Tokyo"),
        ("east coast", "America/New_York"),
        ("Porto", "Europe/Lisbon"),       // via the bundled gazetteer
        ("PST", "America/Los_Angeles"),   // via Foundation's abbreviations
    ])
    func abareZoneTokenConvertsTheCurrentClock(
        input: String,
        expectedTargetIdentifier: String
    ) throws {
        let request = try #require(self.request(for: input))
        #expect(request.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(request.sourceZone.isDeviceLocalZone)
        #expect(request.targetZone.timeZone.identifier == expectedTargetIdentifier)
        #expect(!request.targetZone.isDeviceLocalZone)
    }

    // MARK: The time is now, to the minute

    @Test func thetimeIsTheInjectedNowIncludingItsMinutes() throws {
        let request = try #require(self.request(for: "ET"))
        #expect(request.time == ParsedTime(hour: 15, minute: 42))
    }

    /// Minutes survive all the way to the rendered result, on both sides — a
    /// bare-zone conversion that showed 3:00 pm would be quietly wrong.
    @Test func minutesSurviveIntoTheRenderedResult() {
        #expect(echoLine(for: "ET")
            == "3:42 pm Los Angeles (local, UTC-8) "
                + "→ 6:42 pm Eastern Time (New York, Toronto, UTC-5)")
    }

    /// The clock is read in the *injected* device zone, so changing only that
    /// parameter changes the time as well as the source side.
    @Test func thecurrentClockIsReadInTheInjectedDeviceZone() throws {
        let fromTokyo = try #require(request(for: "ET", localZone: FixedZones.tokyo))
        // 23:42 UTC is 08:42 the next morning in Tokyo.
        #expect(fromTokyo.time == ParsedTime(hour: 8, minute: 42))
        #expect(fromTokyo.sourceZone.timeZone == FixedZones.tokyo)
    }

    // MARK: The (local) marker, and the rest of the display model

    /// The source side is a defaulted side like any other, so it reuses item
    /// 14's marker rather than inventing a second way to say the same thing.
    @Test func thesourceSideCarriesTheExistingLocalMarker() throws {
        let state = presenter.displayState(
            for: "Tokyo",
            now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        )
        let display = try #require(state.convertedDisplay)
        #expect(display.sourceEchoLine == "Los Angeles (local) · 3:42 PM")
        #expect(display.sourcePlaceName == "Los Angeles (local)")
        #expect(display.sourceClockDigits == "3:42")
        #expect(display.sourceMeridiem == "PM")
    }

    /// Everything downstream of the request is the ordinary display model: the
    /// target band, the zone line, the rollover note and the footer sentence
    /// all come out without a single bare-zone special case.
    @Test func theresultBandAndFooterComeOutOfTheNormalDisplayModel() throws {
        let display = try #require(presenter.displayState(
            for: "Tokyo",
            now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        ).convertedDisplay)
        #expect(display.targetPlaceLabel == "In Tokyo")
        #expect(display.targetClockDigits == "8:42")
        #expect(display.targetMeridiem == "AM")
        #expect(display.targetZoneLine == "Japan Standard Time (Tokyo) · next day")
        #expect(display.footerSentence == "Tokyo is 17 hours ahead of Los Angeles.")
    }

    /// An abbreviation target keeps item 21's header shape, which is the proof
    /// that the bare token reached the chain the normal way.
    @Test func anabbreviationTargetKeepsItsItem21Header() throws {
        let display = try #require(presenter.displayState(
            for: "ET",
            now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        ).convertedDisplay)
        #expect(display.targetPlaceLabel == "In ET (Eastern Time)")
        #expect(display.targetZoneLine == "New York, Toronto")
    }

    // MARK: Daylight saving

    /// Same device wall clock, six months apart: the conversion follows both
    /// zones' DST at the injected instant rather than a frozen offset.
    @Test func thecurrentConversionIsDaylightSavingCorrect() {
        #expect(echoLine(for: "Tokyo", now: FixedDates.winterAfternoonWithMinutes)
            == "3:42 pm Los Angeles (local, UTC-8) → 8:42 am Tokyo (UTC+9) +1d")
        #expect(echoLine(for: "Tokyo", now: FixedDates.summerAfternoonWithMinutes)
            == "3:42 pm Los Angeles (local, UTC-7) → 7:42 am Tokyo (UTC+9) +1d")
    }

    /// And on the target side, where the offset itself moves: London is UTC+0
    /// in January and UTC+1 in July.
    @Test func thetargetSideFollowsItsOwnDaylightSaving() {
        #expect(echoLine(for: "London", now: FixedDates.winterAfternoonWithMinutes)
            == "3:42 pm Los Angeles (local, UTC-8) → 11:42 pm London (UTC+0)")
        #expect(echoLine(for: "London", now: FixedDates.summerAfternoonWithMinutes)
            == "3:42 pm Los Angeles (local, UTC-7) → 11:42 pm London (UTC+1)")
    }

    // MARK: P4 — a bare ambiguous token still prompts

    /// The structural rule deliberately does not require the token to
    /// *resolve*, so `CST` reaches its picker instead of collapsing into "no
    /// time found".
    @Test func abareAmbiguousTokenPromptsP4AgainstTheTargetSide() throws {
        let prompt = try #require(parser.parse(
            "CST", now: FixedDates.winterAfternoonWithMinutes, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == .target)
        #expect(prompt.offendingToken == "cst")
        #expect(prompt.ambiguousChoices?.map(\.representativeCity) == ["Chicago", "Shanghai"])
    }

    /// A bare country with no national clock prompts the same way.
    @Test func abareAmbiguousCountryPromptsP4() throws {
        let prompt = try #require(parser.parse(
            "Australia", now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.offendingToken == "australia")
    }

    /// The chip has to rewrite the range of the *bare* token — the whole input
    /// — and the rewritten sentence has to convert on its own.
    @Test func thep4ChipRewritesTheWholeBareTokenAndThenConverts() throws {
        let input = "CST"
        let state = presenter.displayState(
            for: input, now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        )
        let chicago = try #require(state.problemChips?.first)
        #expect(chicago.replacementRange == rawRange(of: "CST", in: input))
        let rewritten = chicago.applied(to: input)
        #expect(rewritten == "Chicago")
        #expect(echoLine(for: rewritten)
            == "3:42 pm Los Angeles (local, UTC-8) → 5:42 pm Chicago (UTC-6)")
    }

    // MARK: P5 — a bare unknown token still prompts

    @Test func abareUnknownTokenPromptsP5WithItsDidYouMeanChips() throws {
        let input = "Lodnon"
        let prompt = try #require(parser.parse(
            input, now: FixedDates.winterAfternoonWithMinutes, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt == .unknownZone(
            token: "lodnon",
            side: .target,
            tokenRange: rawRange(of: "Lodnon", in: input)
        ))

        let state = presenter.displayState(
            for: input, now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        )
        let londonChip = try #require(state.problemChips?.first { $0.label == "London?" })
        let corrected = londonChip.applied(to: input)
        #expect(corrected == "London")
        #expect(echoLine(for: corrected)
            == "3:42 pm Los Angeles (local, UTC-8) → 11:42 pm London (UTC+0)")
    }

    /// Case and spacing are folded for a bare token exactly as for any other,
    /// and a multi-word token keeps its raw span so a chip could rewrite the
    /// whole phrase.
    @Test(arguments: ["east coast", "East Coast", "EAST COAST", "  east   coast  "])
    func abareTokenIsCaseAndSpacingInsensitive(input: String) throws {
        let request = try #require(self.request(for: input))
        #expect(request.targetZone.timeZone.identifier == "America/New_York")
    }

    // MARK: The structural tokenizer rule

    /// What the tokenizer does when no time matched: the whole trimmed,
    /// normalised input becomes one target-side zone token, with no time.
    @Test func thetokenizerEmitsOneTargetTokenAndNoTime() throws {
        let rawInput = "  East   Coast  "
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.time == nil)
        #expect(tokens.sourceZone == nil)
        #expect(tokens.conjunction == nil)
        #expect(tokens.targetZoneToken == "east coast")
        let targetZone = try #require(tokens.targetZone)
        #expect(RawTextEditing.substring(of: targetZone.rawRange, in: rawInput)
            == "East   Coast")
    }

    /// The three structural rejections, each with its reason. These are the
    /// only inputs that still reach P1 without a time, and none of them could
    /// name a place.
    @Test(arguments: [
        "",                 // nothing typed
        "   ",              // whitespace only
        "!!!",              // no word in it
        "12",               // digits read as a half-typed time
        "7",
        "12:",
        "25:00",            // an invalid time, not a zone called "25:00"
        "13:00 am",         // a contradictory meridiem stays a failed time
        "london to paris",  // a conversion sentence that forgot its time
        "et in london",
    ])
    func structurallyImpossibleZoneTokensStillPromptP1(input: String) throws {
        let prompt = try #require(parser.parse(
            input, now: FixedDates.winterAfternoonWithMinutes, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.specIdentifier == "P1")
    }

    /// The digit-only decision, stated on its own because it was a judgement
    /// call rather than a consequence: `12` is not a time in the grammar (the
    /// 24-hour form needs its minutes) and it is not a zone name either, and we
    /// resolve the tie towards P1 — somebody typing digits is starting a time,
    /// and "Couldn't find a time" is the useful half of the truth.
    @Test(arguments: ["12", "1234", "9", "06"])
    func digitOnlyInputsStayP1RatherThanBecomingUnknownZones(input: String) throws {
        let prompt = try #require(parser.parse(
            input, now: FixedDates.winterAfternoonWithMinutes, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.specIdentifier == "P1")
        #expect(prompt.message == "Couldn't find a time — start with e.g. 14:30 or 2:30 pm")
    }

    // MARK: Nothing else moved

    /// The pre-existing rule, restated as a regression: a time *with* a bare
    /// zone is still "that time there, converted to local", which is the
    /// opposite direction from a bare zone on its own.
    @Test func atimeWithAZoneIsUnaffectedAndStillRunsTheOtherWay() throws {
        let request = try #require(self.request(for: "8pm ET"))
        #expect(request.time == ParsedTime(hour: 20, minute: 0))
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
        #expect(request.targetZone.timeZone == FixedZones.losAngeles)
        #expect(request.targetZone.isDeviceLocalZone)
    }

    /// And the empty field is still the quiet hint state rather than a prompt.
    @Test func anemptyFieldIsStillTheHintState() {
        #expect(presenter.displayState(
            for: "   ", now: FixedDates.winterAfternoonWithMinutes,
            localZone: FixedZones.losAngeles
        ) == .hint)
    }
}
