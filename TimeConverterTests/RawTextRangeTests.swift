import Testing
import Foundation
@testable import TimeConverter

/// Item 7's foundation: the normalised/raw offset map, and the zone-token
/// ranges the tokenizer builds from it.
///
/// Every case here is a way normalisation can shift offsets — case folding,
/// collapsed runs, leading padding — because a chip that rewrites the wrong
/// characters is worse than no chip at all.
struct RawTextRangeTests {
    // MARK: Normalisation keeps its old contract

    @Test func normalizationStillTrimsCollapsesAndLowercases() {
        #expect(InputTokenizer.normalize("  12PM   ET   IN   LONDON  ") == "12pm et in london")
        #expect(InputTokenizer.normalize("9:30 AM\tNew  York\nto Lisbon")
            == "9:30 am new york to lisbon")
    }

    // MARK: Offsets address the raw string, not the normalised one

    @Test(arguments: [
        // Lowercasing alone: raw and normalised offsets coincide.
        ("12pm cst in london", "cst", "london"),
        // Case folding: the range must still cover the typed capitals.
        ("12PM CST IN LONDON", "CST", "LONDON"),
        // Leading padding and collapsed runs push every raw offset right.
        ("   12pm    CST    in    London  ", "CST", "London"),
        // A multi-word token's range spans the whitespace the user typed.
        ("9am  New   York  to  Narnia", "New   York", "Narnia"),
    ])
    func zoneTokenRangesAddressTheRawCharactersTheUserTyped(
        rawInput: String,
        expectedSourceSubstring: String,
        expectedTargetSubstring: String
    ) throws {
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected \(rawInput) to tokenize")
            return
        }
        let sourceZone = try #require(tokens.sourceZone)
        let targetZone = try #require(tokens.targetZone)
        #expect(RawTextEditing.substring(of: sourceZone.rawRange, in: rawInput)
            == expectedSourceSubstring)
        #expect(RawTextEditing.substring(of: targetZone.rawRange, in: rawInput)
            == expectedTargetSubstring)
    }

    /// The reason ranges are carried through rather than located by searching:
    /// with the same token on both sides, a search cannot tell which side the
    /// prompt is about.
    @Test func identicalTokensOnBothSidesGetDistinctRanges() throws {
        let rawInput = "9am CST to CST"
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected tokens")
            return
        }
        #expect(tokens.sourceZone?.rawRange == RawTextRange(startOffset: 4, endOffset: 7))
        #expect(tokens.targetZone?.rawRange == RawTextRange(startOffset: 11, endOffset: 14))
    }

    /// And the practical consequence: replacing the source side leaves the
    /// target side alone.
    @Test func replacingOneSideLeavesTheOtherUntouched() throws {
        let rawInput = "9am CST to CST"
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected tokens")
            return
        }
        let sourceZone = try #require(tokens.sourceZone)
        let targetZone = try #require(tokens.targetZone)
        #expect(RawTextEditing.replacing(sourceZone.rawRange, with: "Chicago", in: rawInput)
            == "9am Chicago to CST")
        #expect(RawTextEditing.replacing(targetZone.rawRange, with: "Shanghai", in: rawInput)
            == "9am CST to Shanghai")
    }

    // MARK: Prompts carry the range

    @Test func ambiguousAndUnknownPromptsCarryTheirTokenRange() throws {
        let parser = makeParser()

        let ambiguous = try #require(
            parser.parse("9am CST in London", now: FixedDates.winterMidday).promptValue
        )
        #expect(ambiguous.offendingTokenRange == rawRange(of: "CST", in: "9am CST in London"))

        let unknown = try #require(
            parser.parse("9am ET in Lodnon", now: FixedDates.winterMidday).promptValue
        )
        #expect(unknown.offendingTokenRange == rawRange(of: "Lodnon", in: "9am ET in Lodnon"))
    }

    /// P1 and P2 have no single token to rewrite, so they offer no range (and,
    /// in the presenter, no chips). The two single-zone strings that used to
    /// live here now convert, so the cases left are a missing time and a time
    /// with no zone anywhere.
    @Test(arguments: ["hello there", "3pm", "3pm in"])
    func promptsWithoutAnOffendingTokenCarryNoRange(input: String) throws {
        let prompt = try #require(makeParser().parse(input, now: FixedDates.winterMidday).promptValue)
        #expect(prompt.offendingTokenRange == nil)
    }

    // MARK: Range application is defensive

    /// The field can be edited between a prompt being produced and a chip being
    /// tapped. An out-of-bounds range must leave the text alone rather than
    /// trap or corrupt it.
    @Test func anOutOfBoundsRangeLeavesTheInputUnchanged() {
        let range = RawTextRange(startOffset: 40, endOffset: 50)
        #expect(RawTextEditing.replacing(range, with: "London", in: "9am ET in L") == "9am ET in L")
        #expect(RawTextEditing.substring(of: range, in: "9am ET in L") == nil)
    }

    /// Emoji are single `Character`s, so offsets stay aligned with what the
    /// user sees even though the UTF-8 lengths differ.
    @Test func multiScalarCharactersDoNotShiftOffsets() throws {
        let rawInput = "9am 🇬🇧 to Narnia"
        guard case let .tokens(tokens) = InputTokenizer.tokenize(rawInput) else {
            Issue.record("expected tokens")
            return
        }
        let sourceZone = try #require(tokens.sourceZone)
        #expect(RawTextEditing.substring(of: sourceZone.rawRange, in: rawInput) == "🇬🇧")
        #expect(RawTextEditing.replacing(sourceZone.rawRange, with: "UK", in: rawInput)
            == "9am UK to Narnia")
    }
}
