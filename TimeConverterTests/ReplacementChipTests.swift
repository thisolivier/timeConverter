import Testing
import Foundation
@testable import TimeConverter

/// Items 7 and 9 at the presenter level: the chips a prompt offers, and the
/// edit each one performs on the typed sentence.
///
/// Presenter tests rather than UI tests, for the same reason the rest of the
/// interface is covered this way — `PromptChipRow` is a `ForEach` over values
/// that arrive fully prepared, so testing the values tests the behaviour.
struct ReplacementChipTests {
    private let presenter = ConverterPresenter()

    private func chips(for input: String) -> [ReplacementChip] {
        presenter.displayState(for: input, now: FixedDates.winterMidday).problemChips ?? []
    }

    // MARK: Item 7 — P4 candidate chips

    @Test func anAmbiguousAbbreviationOffersOneChipPerCandidate() {
        let chips = chips(for: "9am CST in London")
        #expect(chips.map(\.label) == ["Chicago (UTC-6)", "Shanghai (UTC+8)"])
        #expect(chips.map(\.replacementText) == ["Chicago", "Shanghai"])
    }

    @Test func aNoNationalClockCountryOffersAllOfItsZones() {
        #expect(chips(for: "9am USA to London").map(\.replacementText)
            == ["New York", "Chicago", "Denver", "Los Angeles", "Anchorage", "Honolulu"])
    }

    /// The guiding rule: a tap edits the sentence. Nothing else is stored.
    @Test func tappingACandidateRewritesTheTokenInPlace() throws {
        let input = "9am CST to IST"
        let chicago = try #require(chips(for: input).first)
        #expect(chicago.applied(to: input) == "9am Chicago to IST")
    }

    /// …and the rewritten sentence re-parses to the *next* prompt, which is
    /// what makes two ambiguities resolvable by two taps.
    @Test func aTapLandsOnTheNextPromptWhenThereIsOne() throws {
        let firstChip = try #require(chips(for: "9am CST to IST").first)
        let afterFirstTap = firstChip.applied(to: "9am CST to IST")
        #expect(afterFirstTap == "9am Chicago to IST")

        let secondState = presenter.displayState(for: afterFirstTap, now: FixedDates.winterMidday)
        #expect(secondState.problemMessage?.hasPrefix("'ist' could mean") == true)

        let secondChip = try #require(secondState.problemChips?.first)
        let afterSecondTap = secondChip.applied(to: afterFirstTap)
        #expect(afterSecondTap == "9am Chicago to Kolkata")
        #expect(presenter.displayState(for: afterSecondTap, now: FixedDates.winterMidday)
            .convertedDisplay != nil)
    }

    /// Ambiguity on the target side rewrites the target side.
    @Test func aTargetSideChipRewritesTheTargetSide() throws {
        let input = "9am London in Australia"
        let chip = try #require(chips(for: input).first)
        #expect(chip.applied(to: input) == "9am London in Sydney")
    }

    /// Case folding and collapsed whitespace must not shift the edit.
    @Test func chipsEditRawTextThroughNormalisation() throws {
        let input = "  9AM   CST   IN   LONDON  "
        let chip = try #require(chips(for: input).first)
        #expect(chip.applied(to: input) == "  9AM   Chicago   IN   LONDON  ")
    }

    /// The chip contract: whatever a chip writes into the sentence must be
    /// something the resolver chain can read back. A chip labelled with a city
    /// the chain does not index would hand the user a fresh P5, which is worse
    /// than the ambiguity it replaced.
    ///
    /// Exhaustive over every token that can produce a P4, because the failure
    /// mode is OS-dependent: the tables name canonical IANA identifiers, and a
    /// given OS release may ship the *link* name instead (`Asia/Calcutta` for
    /// `Asia/Kolkata`), leaving the modern city unindexed.
    @Test func everyAmbiguityChipWritesATokenTheChainCanResolve() throws {
        let ambiguousAliases = AliasZoneTable.meaningsByAlias
            .filter { $0.value.count > 1 }
            .keys
        let ambiguousCountries = CountryZoneTable.zonesByCountryName
            .filter { $0.value.candidateIdentifiers.count > 1 }
            .keys

        for token in Array(ambiguousAliases) + Array(ambiguousCountries) {
            let input = "9am \(token) in London"
            let chips = chips(for: input)
            #expect(!chips.isEmpty, Comment(rawValue: "\(token) produced no chips"))
            for chip in chips {
                let rewritten = chip.applied(to: input)
                #expect(
                    presenter.displayState(for: rewritten, now: FixedDates.winterMidday)
                        .convertedDisplay != nil,
                    Comment(rawValue: "'\(rewritten)' does not convert")
                )
            }
        }
    }

    /// Every chip in a row is distinguishable, or `ForEach` would collapse rows.
    @Test func chipIdentifiersAreUniqueWithinARow() {
        for input in ["9am CST in London", "9am USA to London", "9am ET in Lodnon"] {
            let identifiers = chips(for: input).map(\.id)
            #expect(Set(identifiers).count == identifiers.count, "duplicate ids for \(input)")
        }
    }

    // MARK: Item 9 — P5 did-you-mean chips

    @Test func anUnknownCityOffersItsNearestNeighboursAsChips() {
        let chips = chips(for: "9am ET in Lodnon")
        #expect(chips.map(\.label).contains("London?"))
        #expect(chips.map(\.replacementText).contains("London"))
        #expect(chips.count <= ZoneSuggestionEngine.maximumSuggestionCount)
    }

    /// The whole point, end to end: one tap turns a dead end into a conversion.
    @Test func tappingADidYouMeanChipProducesAConversion() throws {
        let input = "12pm ET in Lodnon"
        let londonChip = try #require(chips(for: input).first { $0.label == "London?" })
        let corrected = londonChip.applied(to: input)
        #expect(corrected == "12pm ET in London")
        #expect(presenter.displayState(for: corrected, now: FixedDates.winterMidday)
            .convertedDisplay != nil)
    }

    /// Six typo rows from `docs/qa-input-candidates.md` §3, each of which must
    /// now offer its intended place as a chip.
    @Test(arguments: [
        ("12pm ET in Lodnon", "London?"),
        ("12pm ET in Londn", "London?"),
        ("12pm ET in Lonndon", "London?"),
        ("12pm ET in Toyko", "Tokyo?"),
        ("12pm ET in Pairs", "Paris?"),
        ("12pm ET in new yrok", "New York?"),
        ("12pm ET in Los Angelos", "Los Angeles?"),
        ("06:34 Portgual in PST", "Portugal?"),
    ])
    func qaListTypoRowsOfferTheIntendedPlace(input: String, expectedLabel: String) {
        #expect(chips(for: input).map(\.label).contains(expectedLabel))
    }

    /// Never auto-accept, not even a unique distance-1 match: the prompt and
    /// the chip both stay, and no conversion happens until the tap.
    @Test func aUniqueCloseMatchIsStillOnlyASuggestion() {
        let state = presenter.displayState(for: "12pm ET in Londn", now: FixedDates.winterMidday)
        #expect(state.convertedDisplay == nil)
        #expect(state.problemMessage?.contains("Don't recognize 'londn'") == true)
        #expect(state.problemChips?.isEmpty == false)
    }

    /// The editorial guard, at the level the user sees it: a mistyped zone code
    /// gets the prompt and no misleading chips.
    @Test func aMistypedZoneCodeOffersNoChips() {
        #expect(chips(for: "12pm RT in London").isEmpty)
    }

    // MARK: Prompts with nothing to correct

    @Test(arguments: ["hello there", "3pm in Tokyo", "06:34 Portugal"])
    func promptsWithoutAnOffendingTokenOfferNoChips(input: String) {
        #expect(chips(for: input).isEmpty)
    }

    @Test func conversionsAndTheHintCarryNoChips() {
        #expect(presenter.displayState(for: "12pm ET in London", now: FixedDates.winterMidday)
            .problemChips == nil)
        #expect(presenter.displayState(for: "", now: FixedDates.winterMidday) == .hint)
    }
}
