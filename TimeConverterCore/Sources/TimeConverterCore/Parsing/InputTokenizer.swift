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
///
/// Since the 2026-10-23 amendment (item 22) the **time** may also be absent: an
/// input that is only a zone token ("ET", "Tokyo", "east coast") converts the
/// current clock, so the time is left nil here and filled in by `InputParser`
/// from the injected `now`. Deciding *whether* the input is such a token is
/// purely structural — see `bareZoneTokens` — because resolution must still be
/// allowed to fail into P4 or P5 rather than silently falling back to P1.
///
/// The leading time may also be the keyword **`now`** (item 23): `now in
/// Bangkok` splits exactly like `7pm in Bangkok`, but leaves the time nil so
/// `InputParser` reads the current clock. `now` is a time, never a zone — only
/// the leading word is checked, so `9am in now` is an ordinary (unknown) target.
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
        /// Nil for a bare-zone input ("ET"), which means "the current clock":
        /// `InputParser` substitutes the wall clock of the injected `now` read
        /// in the injected device zone. Never nil when any zone side was typed
        /// alongside a time, so "8pm ET" is unaffected. Also nil for a leading
        /// `now` (item 23), with the same meaning.
        let time: ParsedTime?
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

        guard let leadingTime = leadingTime(in: normalizedInput) else {
            // No time: the whole input may still be a bare zone token naming
            // where to read the current clock (item 22). P1 is what's left when
            // it structurally cannot be one.
            guard let bareZone = bareZoneTokens(in: normalized) else {
                return .prompt(.timeNotFound(input: normalizedInput))
            }
            return .tokens(bareZone)
        }

        let remainingWords = words(
            in: leadingTime.remainder,
            startingAtNormalizedOffset: leadingTime.remainderStartOffset
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
                return .prompt(.zoneNotFound(time: leadingTime.time))
            }
            return .tokens(Tokens(
                time: leadingTime.time,
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
            return .prompt(.zoneNotFound(time: leadingTime.time))
        }

        return .tokens(Tokens(
            time: leadingTime.time,
            sourceZone: sourceZone,
            conjunction: conjunction,
            targetZone: targetZone
        ))
    }

    // MARK: - Leading time

    /// The time at the start of the input and whatever follows it. `time` is
    /// nil when the user typed the `now` keyword (item 23) — the current clock,
    /// which only `InputParser` can read, since it alone holds the injected
    /// `now`.
    private struct LeadingTime {
        let time: ParsedTime?
        let remainder: String
        let remainderStartOffset: Int
    }

    private static let nowKeyword = "now"

    /// A clock time from `TimeTokenParser`, else a standalone leading `now`
    /// (`now`, `now in tokyo` — but not `nowhere`), else nil for "no time".
    private static func leadingTime(in normalizedInput: String) -> LeadingTime? {
        if let timeMatch = TimeTokenParser.match(atStartOf: normalizedInput) {
            return LeadingTime(
                time: timeMatch.time,
                remainder: timeMatch.remainder,
                remainderStartOffset: timeMatch.remainderStartOffset
            )
        }
        guard normalizedInput == nowKeyword || normalizedInput.hasPrefix(nowKeyword + " ") else {
            return nil
        }
        // Normalised input has single spaces, so the remainder starts one
        // character past the keyword (or is empty for a bare `now`).
        let remainderStartOffset = min(nowKeyword.count + 1, normalizedInput.count)
        return LeadingTime(
            time: nil,
            remainder: String(normalizedInput.dropFirst(remainderStartOffset)),
            remainderStartOffset: remainderStartOffset
        )
    }

    // MARK: - Bare zone (item 22)

    /// Treats the entire normalised input as one zone token — the target, with
    /// the source left to default to the device zone — when it could plausibly
    /// name a place, and returns nil to mean P1 when it could not.
    ///
    /// The test is deliberately **structural**, never "did it resolve": a bare
    /// `Lodnon` has to reach P5's did-you-mean chips and a bare `CST` has to
    /// reach P4's picker, which it cannot do if an unresolvable token quietly
    /// becomes "couldn't find a time". So the three rejections below are all
    /// about the *shape* of the text:
    ///
    /// - **Starts with a digit** (`12`, `13:00 am`, `25:00 london`, `6 et in
    ///   london`): no zone name begins with a digit, and a user who has typed
    ///   digits is partway through a time — which is exactly what P1 says. This
    ///   is why bare `12` stays P1 rather than becoming an unknown zone.
    /// - **Contains no letter at all** (`!!!`, `---`): names are made of words.
    /// - **Contains a standalone conjunction** (`london to paris`): the user has
    ///   written a conversion sentence and left out the time, so P1's "start
    ///   with e.g. 14:30" is the useful answer, not "don't recognize 'london to
    ///   paris'". Multi-word zone names are untouched — `east coast` and `south
    ///   africa` contain no standalone `in`/`to`, and `porto` never did.
    private static func bareZoneTokens(in normalized: NormalizedInput) -> Tokens? {
        let normalizedInput = normalized.normalizedText
        guard let firstCharacter = normalizedInput.first,
              !firstCharacter.isNumber,
              normalizedInput.contains(where: \.isLetter)
        else { return nil }

        let allWords = words(in: normalizedInput, startingAtNormalizedOffset: 0)
        guard !allWords.contains(where: { Conjunction(rawValue: $0.text) != nil }) else {
            return nil
        }
        guard let bareZoneToken = zoneToken(from: allWords, in: normalized) else { return nil }

        // The named zone is the *target*: "ET" asks what the local clock reads
        // over there, so the source is the device zone — the same shape as
        // "7pm in London", and the same `(local)` marker on the echo.
        return Tokens(
            time: nil,
            sourceZone: nil,
            conjunction: nil,
            targetZone: bareZoneToken
        )
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
