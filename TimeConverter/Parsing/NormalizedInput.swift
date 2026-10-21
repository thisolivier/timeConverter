import Foundation

/// The normalised working copy of the user's input, *plus* the map back to the
/// raw string it came from.
///
/// The spec's tokenisation step 1 is "trim, collapse whitespace, lowercase".
/// That throws away the correspondence between a token and the characters the
/// user actually typed, which is exactly what tap-to-replace chips need. So
/// normalisation is done one character at a time here, recording for every
/// normalised character the raw offset that produced it.
///
/// Two details the naive `input.lowercased()` gets wrong and this does not:
/// - **Collapsed whitespace.** `"New   York"` normalises to `"new york"`, nine
///   characters shorter than the raw run it came from. Zone tokens never begin
///   or end with whitespace, so mapping a token's first and last characters is
///   enough to recover the whole raw span including the inner runs.
/// - **Length-changing lowercasing.** A few characters lowercase to more than
///   one character (`İ` → `i̇`). Mapping per source character keeps the two
///   strings aligned instead of assuming equal lengths.
struct NormalizedInput: Equatable, Sendable {
    /// What the user typed, untouched.
    let rawInput: String
    /// Trimmed, whitespace-collapsed, lowercased.
    let normalizedText: String
    /// `rawOffsetsByNormalizedOffset[i]` is the raw `Character` offset of the
    /// character that produced `normalizedText[i]`.
    private let rawOffsetsByNormalizedOffset: [Int]

    static func normalizing(_ rawInput: String) -> NormalizedInput {
        var normalizedCharacters: [Character] = []
        var rawOffsets: [Int] = []
        var hasEmittedAnyCharacter = false
        var separatorIsPending = false

        for (rawOffset, rawCharacter) in rawInput.enumerated() {
            guard !rawCharacter.isWhitespace else {
                // Leading whitespace is dropped; interior runs become a single
                // space, emitted lazily so trailing whitespace is dropped too.
                if hasEmittedAnyCharacter { separatorIsPending = true }
                continue
            }
            if separatorIsPending {
                normalizedCharacters.append(" ")
                // The separator is attributed to the character that follows it.
                // Harmless: tokens never start or end on a space, so no token
                // range is ever anchored to this entry.
                rawOffsets.append(rawOffset)
                separatorIsPending = false
            }
            for lowercasedCharacter in rawCharacter.lowercased() {
                normalizedCharacters.append(lowercasedCharacter)
                rawOffsets.append(rawOffset)
            }
            hasEmittedAnyCharacter = true
        }

        return NormalizedInput(
            rawInput: rawInput,
            normalizedText: String(normalizedCharacters),
            rawOffsetsByNormalizedOffset: rawOffsets
        )
    }

    /// Translates a half-open range of normalised character offsets into the
    /// raw range it came from.
    ///
    /// Returns nil for an empty or out-of-bounds range — a caller asking about
    /// a token that is not there should get nothing, not a guess.
    func rawRange(forNormalizedOffsets normalizedRange: Range<Int>) -> RawTextRange? {
        guard !normalizedRange.isEmpty,
              normalizedRange.lowerBound >= 0,
              normalizedRange.upperBound <= rawOffsetsByNormalizedOffset.count
        else { return nil }
        let firstRawOffset = rawOffsetsByNormalizedOffset[normalizedRange.lowerBound]
        let lastRawOffset = rawOffsetsByNormalizedOffset[normalizedRange.upperBound - 1]
        return RawTextRange(startOffset: firstRawOffset, endOffset: lastRawOffset + 1)
    }
}
