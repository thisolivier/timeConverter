import Foundation

/// Splits a freeform string into its grammar parts, per the spec's
/// tokenization steps: normalise, match the time at the start, then find the
/// **first standalone** conjunction and cut the rest in two around it.
///
/// Since the 2026-10-22 amendment a side may legitimately be **empty**: the
/// conjunction decides which side a lone named zone belongs to, and the other
/// side is filled in from the device zone by `InputParser` (never here — the
/// tokenizer has no business knowing about zones at all). `7pm in London`
/// leaves the source empty, `7pm east coast` leaves the target empty, and only
/// a time with no zone on *either* side is a prompt.
///
/// Every zone token comes out with a `RawTextRange` addressing the characters
/// the user actually typed, so a prompt can later offer a chip that rewrites
/// precisely that span (backlog items 7 and 9). The ranges are produced by
/// `NormalizedInput`, which keeps the normalised/raw correspondence rather than
/// re-locating tokens by searching — `9am CST to CST` must rewrite the side the
/// prompt is about, and a search cannot know which that is.
enum InputTokenizer {
    /// One zone token: the normalised text the resolvers see, and where it came
    /// from in the raw input.
    struct ZoneToken: Equatable, Sendable {
        let text: String
        let rawRange: RawTextRange
    }

    /// At least one of `sourceZone` and `targetZone` is always non-nil: a time
    /// with no zone at all is P2, so the tokenizer never emits two empty sides.
    struct Tokens: Equatable, Sendable {
        let time: ParsedTime
        /// Nil when the user named only the target (`7pm in London`), in which
        /// case the source defaults to the injected device zone.
        let sourceZone: ZoneToken?
        /// Nil when no standalone conjunction was typed (`7pm east coast`).
        let conjunction: Conjunction?
        /// Nil when the user named only the source (`7pm east coast`), in which
        /// case the target defaults to the injected device zone.
        let targetZone: ZoneToken?

        var sourceZoneToken: String? { sourceZone?.text }
        var targetZoneToken: String? { targetZone?.text }
    }

    enum Result: Equatable, Sendable {
        case tokens(Tokens)
        case prompt(Prompt)
    }

    /// Trim, collapse runs of whitespace to single spaces, lowercase.
    /// Matching is case-insensitive throughout, so everything downstream of
    /// here works on the lowercased copy.
    static func normalize(_ input: String) -> String {
        NormalizedInput.normalizing(input).normalizedText
    }

    static func tokenize(_ input: String) -> Result {
        let normalized = NormalizedInput.normalizing(input)
        let normalizedInput = normalized.normalizedText

        guard let timeMatch = TimeTokenParser.match(atStartOf: normalizedInput) else {
            return .prompt(.timeNotFound(input: normalizedInput))
        }

        let remainingWords = words(
            in: timeMatch.remainder,
            startingAtNormalizedOffset: timeMatch.remainderStartOffset
        )

        // Scanning for the *first* standalone conjunction is what keeps "Porto"
        // safe: "to" inside a word is not a word, so it never splits. It also
        // means a zone name containing a standalone "in"/"to" between the two
        // zones cannot occur — an accepted limitation of the closed list.
        let conjunctionIndex = remainingWords.firstIndex { word in
            Conjunction(rawValue: word.text) != nil
        }

        guard let conjunctionIndex else {
            // No conjunction: whatever follows the time is where the time *is*,
            // so it is the source, and the target defaults to local
            // ("7pm east coast"). Multi-word names survive because every
            // remaining word goes into the one token.
            guard let sourceZone = zoneToken(from: remainingWords, in: normalized) else {
                // Nothing but a time: there is no zone to convert between.
                return .prompt(.zoneNotFound(time: timeMatch.time))
            }
            return .tokens(Tokens(
                time: timeMatch.time,
                sourceZone: sourceZone,
                conjunction: nil,
                targetZone: nil
            ))
        }

        let conjunction = Conjunction(rawValue: remainingWords[conjunctionIndex].text)!
        let sourceWords = Array(remainingWords[..<conjunctionIndex])
        let targetWords = Array(remainingWords[(conjunctionIndex + 1)...])
        let sourceZone = zoneToken(from: sourceWords, in: normalized)
        let targetZone = zoneToken(from: targetWords, in: normalized)

        // A conjunction with nothing on either side of it ("7pm in") names no
        // zone at all, so there is still nothing to convert between.
        guard sourceZone != nil || targetZone != nil else {
            return .prompt(.zoneNotFound(time: timeMatch.time))
        }

        return .tokens(Tokens(
            time: timeMatch.time,
            sourceZone: sourceZone,
            conjunction: conjunction,
            targetZone: targetZone
        ))
    }

    // MARK: - Word scanning

    /// A single whitespace-delimited word with its offsets inside the
    /// normalised string.
    private struct Word {
        let text: String
        let normalizedRange: Range<Int>
    }

    /// Splits an already-normalised fragment into words, converting each word's
    /// offset within the fragment into an offset within the whole normalised
    /// input. The fragment has single-space separators and no padding, so a
    /// running counter is exact.
    private static func words(
        in normalizedFragment: String,
        startingAtNormalizedOffset fragmentStartOffset: Int
    ) -> [Word] {
        var scannedWords: [Word] = []
        var offsetWithinFragment = 0
        for wordText in normalizedFragment.split(separator: " ", omittingEmptySubsequences: false) {
            if !wordText.isEmpty {
                let start = fragmentStartOffset + offsetWithinFragment
                scannedWords.append(Word(
                    text: String(wordText),
                    normalizedRange: start..<(start + wordText.count)
                ))
            }
            offsetWithinFragment += wordText.count + 1 // the separator
        }
        return scannedWords
    }

    private static func joinedText(of words: [Word]) -> String {
        words.map(\.text).joined(separator: " ")
    }

    /// Spans the words from the first character of the first to the last
    /// character of the last, so a multi-word token's raw range covers whatever
    /// whitespace the user typed between them. Returns nil for an empty side,
    /// which is a missing-zone prompt rather than a token.
    private static func zoneToken(from words: [Word], in normalized: NormalizedInput) -> ZoneToken? {
        guard let first = words.first, let last = words.last else { return nil }
        let normalizedRange = first.normalizedRange.lowerBound..<last.normalizedRange.upperBound
        guard let rawRange = normalized.rawRange(forNormalizedOffsets: normalizedRange) else {
            return nil
        }
        return ZoneToken(text: joinedText(of: words), rawRange: rawRange)
    }
}
