import Testing
import Foundation
@testable import TimeConverter

/// Item 9 — the did-you-mean suggester, including the editorial policy that
/// decides which vocabulary is worth suggesting at all.
///
/// The typo fixtures are lifted from `docs/qa-input-candidates.md` §3 (Typos),
/// which is item 6's review output: those are the strings a real person types
/// fast, so they are the ones the suggester has to catch.
struct ZoneSuggestionEngineTests {
    private let chain = ZoneResolverChain.standard

    private func suggestedTokens(for typo: String) -> [String] {
        ZoneSuggestionEngine.suggestions(for: typo, in: chain).map(\.token)
    }

    // MARK: Edit distance

    @Test(arguments: [
        ("london", "london", 0),
        ("londn", "london", 1),
        ("lodnon", "london", 2),
        ("lonndon", "london", 1),
    ])
    func boundedEditDistanceAgrees(first: String, second: String, expected: Int) {
        #expect(EditDistance.levenshtein(first, second, limitedTo: 2) == expected)
    }

    @Test func distancesBeyondTheLimitAreRejectedRatherThanReported() {
        #expect(EditDistance.levenshtein("narnia", "london", limitedTo: 2) == nil)
        #expect(EditDistance.levenshtein("a", "abcdef", limitedTo: 2) == nil)
        #expect(EditDistance.levenshtein("", "ab", limitedTo: 2) == 2)
    }

    // MARK: The QA list's typo cases

    /// Lifted verbatim from the QA list's "Misspelled target or source place"
    /// table — the eight rows there whose intended place is in our vocabulary.
    @Test(arguments: [
        ("lodnon", "london"),       // transposition — "the single most likely real typo"
        ("londn", "london"),        // dropped letter
        ("lonndon", "london"),      // doubled letter
        ("toyko", "tokyo"),         // transposition
        ("pairs", "paris"),         // transposition that is also a real word
        ("new yrok", "new york"),   // transposition inside a multi-word city
        ("los angelos", "los angeles"), // very common misspelling
        ("portgual", "portugal"),   // transposition of the spec's own example
    ])
    func qaListTypoCasesSuggestTheIntendedPlace(typo: String, expectedToken: String) {
        let tokens = suggestedTokens(for: typo)
        #expect(tokens.contains(expectedToken), "\(typo) suggested \(tokens)")
    }

    /// `Newyork` is the QA list's missing-space case: a space is one edit, so
    /// the multi-word city is reachable.
    @Test func aMissingSpaceIsASingleEdit() {
        #expect(suggestedTokens(for: "newyork").contains("new york"))
    }

    // MARK: Caps, ranking and dedupe

    @Test func atMostThreeSuggestionsAreOffered() {
        for typo in ["lodnon", "londn", "toyko", "portgual", "pairs", "amsterdm"] {
            #expect(suggestedTokens(for: typo).count <= ZoneSuggestionEngine.maximumSuggestionCount)
        }
    }

    @Test func suggestionsAreOrderedByEditDistance() {
        let suggestions = ZoneSuggestionEngine.suggestions(for: "londn", in: chain)
        #expect(suggestions.map(\.editDistance) == suggestions.map(\.editDistance).sorted())
    }

    @Test func noSuggestionIsRepeatedAcrossChainLevels() {
        // `uk` is in the alias table and `UK`-ish codes recur in Foundation's
        // dictionary; whatever surfaces must surface once.
        for typo in ["uk ", "ukk", "cest", "wst", "londn"] {
            let tokens = suggestedTokens(for: typo)
            #expect(Set(tokens).count == tokens.count, "\(typo) repeated: \(tokens)")
        }
    }

    @Test func aTokenThatResolvesIsNeverSuggestedAsItsOwnCorrection() {
        #expect(!suggestedTokens(for: "london").contains("london"))
    }

    @Test func somethingTrulyUnlikeAnyPlaceGetsNoSuggestions() {
        #expect(suggestedTokens(for: "qqqqqqqqqq").isEmpty)
        #expect(suggestedTokens(for: "").isEmpty)
    }

    // MARK: Editorial policy — abbreviations

    /// The named requirement: zone codes sit one edit from each other, so a
    /// mistyped code must not be answered with a confident wrong code. `cst`
    /// must never offer `cet`, in either direction.
    @Test(arguments: ["cat", "cpt", "cwt", "nst", "mdt "])
    func mutuallyCloseZoneCodesAreWithheld(abbreviationTypo: String) {
        let suggestions = ZoneSuggestionEngine.suggestions(
            for: abbreviationTypo.trimmingCharacters(in: .whitespaces), in: chain
        )
        let offeredCodes = suggestions.filter {
            ZoneSuggestionEngine.isAbbreviationShaped($0.token)
                && $0.matchSource != .timeZoneDatabaseCity
                && $0.matchSource != .countryTable
                && $0.matchSource != .offlineFallbackList
        }
        #expect(offeredCodes.isEmpty, "\(abbreviationTypo) offered \(offeredCodes.map(\.token))")
    }

    @Test func cstAndCetAreNeverOfferedForEachOther() {
        #expect(!suggestedTokens(for: "cet").contains("cst"))
        #expect(!suggestedTokens(for: "cst").contains("cet"))
    }

    /// Withheld is not the same as never: a code with exactly one neighbour is
    /// an unambiguous correction, so it is offered. `PSR` is the QA list's own
    /// mistyped-abbreviation row.
    @Test func aZoneCodeWithASingleNeighbourIsStillOffered() {
        #expect(suggestedTokens(for: "psr").contains("pst"))
    }

    /// `RT` is the QA list's adjacent-key row for `ET`. Two letters put every
    /// one-letter zone code in range at once, so nothing is offered — the
    /// honest outcome.
    @Test func aTwoLetterCodeTypoOffersNoZoneCodes() {
        #expect(suggestedTokens(for: "rt").isEmpty)
    }

    // MARK: Editorial policy — short tokens

    /// Two edits is most of a four-character word, so short tokens are held to
    /// a single edit.
    @Test func shortTokensRequireASingleEdit() {
        // `oslo` is a real city; `oslp` is one edit away and is suggested…
        #expect(suggestedTokens(for: "oslp").contains("oslo"))
        // …while two edits away offers nothing.
        #expect(!suggestedTokens(for: "qslp").contains("oslo"))
    }

    @Test func theLengthThresholdsMatchTheDocumentedPolicy() {
        #expect(ZoneSuggestionEngine.shortTokenLengthThreshold == 4)
        #expect(ZoneSuggestionEngine.maximumSuggestionCount == 3)
    }

    // MARK: Vocabulary exposure

    /// The additive capability itself: every resolver can enumerate what it
    /// matches, and every token it offers really does resolve.
    @Test func everyResolverExposesVocabulary() {
        for resolver in chain.resolvers {
            #expect(!resolver.vocabulary.isEmpty, "\(resolver.matchSource) has no vocabulary")
        }
    }

    @Test func everyVocabularyTokenIsNormalizedAndResolvable() {
        for resolver in chain.resolvers {
            for entry in resolver.vocabulary {
                #expect(entry.token == entry.token.lowercased(), "\(entry.token) is not lowercase")
                #expect(!resolver.candidates(for: entry.token).isEmpty,
                        "\(entry.token) is vocabulary but does not resolve")
            }
        }
    }

    /// The gazetteer's table had to be exposed for this; prove it is reachable
    /// and that `Porto` is suggestible from a typo of it.
    @Test func theOfflineGazetteerContributesVocabulary() {
        let resolver = OfflineFallbackZoneResolver()
        #expect(resolver.vocabulary.map(\.token).contains("porto"))
        #expect(suggestedTokens(for: "prto").contains("porto"))
    }

    /// Alias *codes* are abbreviation-shaped; the table's multi-word
    /// colloquialisms ("east coast", item 14) are phrases and are shaped as
    /// place names, so a chip offers `East Coast` rather than `EAST COAST`.
    @Test func aliasTableVocabularyIsAbbreviationShapedAndCitiesArePlaceShaped() {
        let aliasVocabulary = AliasZoneResolver().vocabulary
        #expect(aliasVocabulary
            .filter { !$0.token.contains(" ") }
            .allSatisfy { $0.shape == .abbreviation })
        #expect(aliasVocabulary
            .filter { $0.token.contains(" ") }
            .allSatisfy { $0.shape == .placeName })
        #expect(FoundationAbbreviationZoneResolver().vocabulary
            .allSatisfy { $0.shape == .abbreviation })
        #expect(TimeZoneDatabaseCityResolver().vocabulary.allSatisfy { $0.shape == .placeName })
        #expect(CountryZoneResolver().vocabulary.allSatisfy { $0.shape == .placeName })
    }

    @Test func labelsAreChipReadyNotRawTokens() {
        #expect(ZoneVocabularyEntry(token: "new york", shape: .placeName, matchSource:
            .timeZoneDatabaseCity).suggestionLabel == "New York")
        #expect(ZoneVocabularyEntry(token: "pst", shape: .abbreviation, matchSource:
            .foundationAbbreviation).suggestionLabel == "PST")
    }
}
