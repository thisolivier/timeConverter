import Testing
import Foundation
@testable import TimeConvertor

/// Normalisation and the first-standalone-conjunction split.
struct InputTokenizerTests {
    @Test func normalizationTrimsCollapsesAndLowercases() {
        #expect(InputTokenizer.normalize("  12PM   ET   IN   LONDON  ") == "12pm et in london")
        #expect(InputTokenizer.normalize("9:30 AM\tNew  York\nto Lisbon")
            == "9:30 am new york to lisbon")
    }

    @Test(arguments: [
        ("12pm ET in London", "et", Conjunction.inWord, "london"),
        ("23:15 UK to Porto", "uk", Conjunction.toWord, "porto"),
        ("9:30 am New York to Lisbon", "new york", Conjunction.toWord, "lisbon"),
        ("06:34 Portugal in PST", "portugal", Conjunction.inWord, "pst"),
    ])
    func conjunctionSplitsTheZoneTokens(
        input: String,
        expectedSource: String,
        expectedConjunction: Conjunction,
        expectedTarget: String
    ) throws {
        guard case let .tokens(tokens) = InputTokenizer.tokenize(input) else {
            Issue.record("expected tokens for \(input)")
            return
        }
        #expect(tokens.sourceZoneToken == expectedSource)
        #expect(tokens.conjunction == expectedConjunction)
        #expect(tokens.targetZoneToken == expectedTarget)
    }

    /// "Porto" contains "to" but not as a standalone word, so it must not split.
    @Test func conjunctionInsideAWordDoesNotSplit() throws {
        guard case let .tokens(tokens) = InputTokenizer.tokenize("23:15 uk to porto") else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.targetZoneToken == "porto")
    }

    /// Only the *first* standalone conjunction splits; later ones stay inside
    /// the target token (and will simply fail to resolve).
    @Test func onlyTheFirstConjunctionSplits() throws {
        guard case let .tokens(tokens) = InputTokenizer.tokenize("12pm et in london in paris") else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.sourceZoneToken == "et")
        #expect(tokens.targetZoneToken == "london in paris")
    }

    @Test func multiWordZonesSurviveOnBothSides() throws {
        guard case let .tokens(tokens) =
            InputTokenizer.tokenize("9am new york to south africa")
        else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.sourceZoneToken == "new york")
        #expect(tokens.targetZoneToken == "south africa")
    }
}
