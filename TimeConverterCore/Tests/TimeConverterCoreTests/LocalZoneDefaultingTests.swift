import Testing
import Foundation
@testable import TimeConverterCore

/// Item 14 — local-zone defaulting for single-zone inputs (spec amended
/// 2026-10-22).
///
/// Two rules, and the conjunction is what tells them apart:
/// `7pm in London` names the **target** (source defaults to local),
/// `7pm east coast` names the **source** (target defaults to local).
///
/// Every test injects a device zone from `FixedZones`. Nothing here reads
/// `TimeZone.current`, which is the whole point of making the device zone a
/// parameter: the echo strings below are exact and stay exact on any machine.
struct LocalZoneDefaultingTests {
    private let parser = makeParser()
    private let presenter = ConverterPresenter()

    private func echoLine(
        for input: String,
        localZone: TimeZone,
        now: Date = FixedDates.winterMidday
    ) -> String? {
        presenter.displayState(for: input, now: now, localZone: localZone)
            .convertedDisplay?.echoLine
    }

    // MARK: A conjunction makes the named zone the target

    @Test func aConjunctionMakesTheNamedZoneTheTargetAndDefaultsTheSource() throws {
        let request = try #require(parser.parse(
            "7pm in London", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).requestValue)
        #expect(request.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(request.sourceZone.isDeviceLocalZone)
        #expect(request.sourceZone.matchSource == .deviceLocalZone)
        #expect(request.targetZone.timeZone.identifier == "Europe/London")
        #expect(!request.targetZone.isDeviceLocalZone)
    }

    /// The spec amendment's own example line, shape for shape. (The spec's
    /// illustration mixes seasons — `UTC-7` beside `UTC+0` — so here it is in
    /// one season: a January evening in Los Angeles is next morning in London.)
    @Test func theDefaultedSourceEchoesWithTheLocalMarker() {
        #expect(echoLine(for: "7pm in London", localZone: FixedZones.losAngeles)
            == "7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d")
    }

    /// The quieter detail line names the defaulted zone's identifier like any
    /// other, so the assumption is visible twice over.
    @Test func thedetailLineNamesTheDefaultedZone() {
        let state = presenter.displayState(
            for: "7pm in London", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        #expect(state.convertedDisplay?.detailLine == "America/Los_Angeles → Europe/London")
    }

    /// Changing only the injected zone changes only the defaulted side — which
    /// is the proof that the zone really is injected rather than read.
    @Test func theDefaultedSideFollowsTheInjectedZone() {
        #expect(echoLine(for: "7pm in London", localZone: FixedZones.tokyo)
            == "7:00 pm Tokyo (local, UTC+9) → 10:00 am London (UTC+0)")
    }

    // MARK: No conjunction makes the named zone the source

    @Test func noConjunctionMakesTheNamedZoneTheSourceAndDefaultsTheTarget() throws {
        let request = try #require(parser.parse(
            "7pm east coast", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).requestValue)
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
        #expect(!request.sourceZone.isDeviceLocalZone)
        #expect(request.targetZone.timeZone == FixedZones.losAngeles)
        #expect(request.targetZone.isDeviceLocalZone)
    }

    /// The marker folds into the existing parenthetical on the target side too,
    /// while the named side keeps its item-13 abbreviation expansion.
    @Test func theDefaultedTargetEchoesWithTheLocalMarker() {
        #expect(echoLine(for: "7pm east coast", localZone: FixedZones.losAngeles)
            == "7:00 pm Eastern Time (New York, Toronto, UTC-5) "
                + "→ 4:00 pm Los Angeles (local, UTC-8)")
    }

    // MARK: Day rollover with a defaulted side

    /// Forwards, with the *source* defaulted (above: `+1d`), and backwards with
    /// the *target* defaulted — a Tokyo morning is the previous day in
    /// California.
    @Test func aDefaultedSideStillProducesTheRolloverMarker() {
        #expect(echoLine(for: "7pm in London", localZone: FixedZones.losAngeles)?
            .hasSuffix("+1d") == true)
        #expect(echoLine(for: "1am tokyo", localZone: FixedZones.losAngeles)
            == "1:00 am Tokyo (UTC+9) → 8:00 am Los Angeles (local, UTC-8) -1d")
    }

    // MARK: The marker means "defaulted", not "equals the device zone"

    /// Typing the local zone's own name is an ordinary named side: the marker
    /// reports that an assumption was made, so it must not appear when the user
    /// made the choice themselves.
    @Test func atypedZoneIsNeverMarkedLocalEvenWhenItIsTheDeviceZone() throws {
        let request = try #require(parser.parse(
            "7pm los angeles to london",
            now: FixedDates.winterMidday,
            localZone: FixedZones.losAngeles
        ).requestValue)
        #expect(request.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(!request.sourceZone.isDeviceLocalZone)
        #expect(echoLine(for: "7pm los angeles to london", localZone: FixedZones.losAngeles)
            == "7:00 pm Los Angeles (UTC-8) → 3:00 am London (UTC+0) +1d")
    }

    /// And an input naming both zones ignores the injected zone entirely.
    @Test func anInputNamingBothZonesIgnoresTheDeviceZone() throws {
        let viaTokyo = try #require(parser.parse(
            "12pm ET in London", now: FixedDates.winterMidday, localZone: FixedZones.tokyo
        ).requestValue)
        let viaLondon = try #require(parser.parse(
            "12pm ET in London", now: FixedDates.winterMidday, localZone: FixedZones.london
        ).requestValue)
        #expect(viaTokyo == viaLondon)
    }

    // MARK: Still nothing to convert between

    @Test(arguments: ["7pm", "7pm in", "7pm to"])
    func atimeWithNoZoneAnywhereStillPrompts(input: String) throws {
        let outcome = parser.parse(
            input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        let prompt = try #require(outcome.promptValue)
        #expect(prompt.specIdentifier == "P2")
        #expect(prompt.message == "Convert 7:00 pm where? Add a timezone, city, or country")
    }

    // MARK: Prompts on the one named zone still work

    /// P5 with a defaulted source: the did-you-mean chip still rewrites the
    /// right token, and one tap lands on a conversion whose source is local.
    @Test func didYouMeanChipsWorkOnTheNamedTargetWithADefaultedSource() throws {
        let input = "7pm in Lodnon"
        let state = presenter.displayState(
            for: input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        #expect(state.problemMessage?.contains("Don't recognize 'lodnon'") == true)

        let prompt = try #require(parser.parse(
            input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.side == .target)
        #expect(prompt.offendingTokenRange == rawRange(of: "Lodnon", in: input))

        let londonChip = try #require(state.problemChips?.first { $0.label == "London?" })
        let corrected = londonChip.applied(to: input)
        #expect(corrected == "7pm in London")
        #expect(presenter.displayState(
            for: corrected, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).convertedDisplay?.echoLine
            == "7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d")
    }

    /// P4 on a single named zone, on both sides of the conjunction rule: the
    /// ambiguity is reported against the side the conjunction puts it on, and
    /// the chip rewrites that token in place.
    @Test(arguments: [
        ("9am CST", ZoneSide.source),
        ("9am in CST", ZoneSide.target),
    ])
    func ambiguityOnTheOneNamedZoneIsReportedAgainstTheRightSide(
        input: String,
        expectedSide: ZoneSide
    ) throws {
        let prompt = try #require(parser.parse(
            input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == expectedSide)
        #expect(prompt.ambiguousChoices?.map(\.representativeCity) == ["Chicago", "Shanghai"])

        let state = presenter.displayState(
            for: input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        )
        let chicago = try #require(state.problemChips?.first)
        let rewritten = chicago.applied(to: input)
        #expect(rewritten == input.replacingOccurrences(of: "CST", with: "Chicago"))
        #expect(presenter.displayState(
            for: rewritten, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).convertedDisplay != nil)
    }

    // MARK: Tokenization of the three shapes

    @Test func theTokenizerLeavesTheDefaultedSideEmpty() throws {
        guard case let .tokens(withConjunction) = InputTokenizer.tokenize("7pm in London") else {
            Issue.record("expected tokens")
            return
        }
        #expect(withConjunction.sourceZone == nil)
        #expect(withConjunction.conjunction == .inWord)
        #expect(withConjunction.targetZoneToken == "london")

        guard case let .tokens(withoutConjunction) = InputTokenizer.tokenize("7pm east coast")
        else {
            Issue.record("expected tokens")
            return
        }
        #expect(withoutConjunction.sourceZoneToken == "east coast")
        #expect(withoutConjunction.conjunction == nil)
        #expect(withoutConjunction.targetZone == nil)
    }

    /// A multi-word zone with no conjunction after it: every remaining word has
    /// to go into the one token, and its raw range has to span the phrase the
    /// user typed, or a chip would rewrite half a name.
    @Test func aMultiWordZoneWithNoConjunctionStaysOneToken() throws {
        let rawInput = "7pm  East   Coast"
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.sourceZoneToken == "east coast")
        let sourceZone = try #require(tokens.sourceZone)
        #expect(RawTextEditing.substring(of: sourceZone.rawRange, in: rawInput)
            == "East   Coast")
    }

    // MARK: The coast aliases

    @Test(arguments: [
        ("east coast", "America/New_York", "Eastern Time"),
        ("west coast", "America/Los_Angeles", "Pacific Time"),
    ])
    func theCoastAliasesResolveWithDisplayMetadata(
        token: String,
        expectedIdentifier: String,
        expectedDisplayName: String
    ) throws {
        guard case let .resolved(zone) = ZoneResolverChain.standard.resolve(token) else {
            Issue.record("\(token) should resolve to exactly one zone")
            return
        }
        #expect(zone.timeZone.identifier == expectedIdentifier)
        #expect(zone.displayName == expectedDisplayName)
        #expect(zone.matchSource == .aliasTable)
        #expect(!zone.representativeCities.isEmpty)
    }

    /// Case folding applies to multi-word aliases as much as to codes.
    @Test(arguments: ["7pm East Coast", "7pm EAST COAST", "7pm  east   coast"])
    func theCoastAliasesAreCaseAndSpacingInsensitive(input: String) throws {
        let request = try #require(parser.parse(
            input, now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).requestValue)
        #expect(request.sourceZone.timeZone.identifier == "America/New_York")
    }

    @Test func theWestCoastAliasConvertsToADefaultedLondonTarget() {
        #expect(echoLine(for: "7pm west coast", localZone: FixedZones.london)
            == "7:00 pm Pacific Time (Los Angeles, Vancouver, UTC-8) "
                + "→ 3:00 am London (local, UTC+0) +1d")
    }

    /// With a conjunction, a coast is the target like any other named zone.
    @Test func acoastAfterAConjunctionIsTheTarget() throws {
        let request = try #require(parser.parse(
            "7pm in west coast", now: FixedDates.winterMidday, localZone: FixedZones.london
        ).requestValue)
        #expect(request.sourceZone.timeZone == FixedZones.london)
        #expect(request.sourceZone.isDeviceLocalZone)
        #expect(request.targetZone.timeZone.identifier == "America/Los_Angeles")
    }

    /// The coasts are phrases, not codes, so a chip offering one reads as a
    /// place name rather than as shouting.
    @Test func theCoastAliasesAreSuggestedAsPlaceNames() {
        let coastEntries = AliasZoneResolver().vocabulary.filter { $0.token.contains("coast") }
        #expect(coastEntries.map(\.token).sorted() == ["east coast", "west coast"])
        #expect(coastEntries.allSatisfy { $0.shape == .placeName })
        #expect(coastEntries.map(\.suggestionLabel).sorted() == ["East Coast", "West Coast"])
    }

    // MARK: Purity

    /// The module-wide rule, stated as a test: a defaulted zone can only come
    /// from the parameter, so two different injections can never agree.
    @Test func theParserNeverFallsBackToTheDeviceZoneItself() throws {
        let viaTokyo = try #require(parser.parse(
            "7pm in London", now: FixedDates.winterMidday, localZone: FixedZones.tokyo
        ).requestValue)
        let viaLosAngeles = try #require(parser.parse(
            "7pm in London", now: FixedDates.winterMidday, localZone: FixedZones.losAngeles
        ).requestValue)
        #expect(viaTokyo.sourceZone.timeZone == FixedZones.tokyo)
        #expect(viaLosAngeles.sourceZone.timeZone == FixedZones.losAngeles)
        #expect(viaTokyo != viaLosAngeles)
    }
}
