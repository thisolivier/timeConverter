import Foundation

/// A half-open range of `Character` offsets into the **raw** string the user
/// typed — not the normalised copy the parser works on.
///
/// The distinction is the whole point. `InputTokenizer` lowercases and collapses
/// whitespace before parsing, so offsets inside the normalised text do not
/// address the same characters as the text in the field. Chip taps (backlog
/// items 7 and 9) rewrite the *typed sentence*, so every range that escapes the
/// tokenizer is translated back to raw offsets first and nothing downstream has
/// to think about normalisation again.
struct RawTextRange: Equatable, Sendable {
    /// Inclusive start, counted in `Character`s from the start of the raw input.
    let startOffset: Int
    /// Exclusive end, same units.
    let endOffset: Int

    init(startOffset: Int, endOffset: Int) {
        self.startOffset = startOffset
        self.endOffset = endOffset
    }

    var isEmpty: Bool { endOffset <= startOffset }
}

/// Applies a `RawTextRange` to a raw string.
///
/// Character offsets rather than `String.Index` because the ranges travel
/// through value types that must stay `Equatable` and `Sendable` and must not
/// hold an index into a string they no longer own.
enum RawTextEditing {
    /// Replaces `range` with `replacement`, or returns the input unchanged if
    /// the range no longer fits the string (the field can have been edited since
    /// the prompt was produced, in which case doing nothing is the safe answer).
    static func replacing(
        _ range: RawTextRange,
        with replacement: String,
        in rawInput: String
    ) -> String {
        guard let stringRange = stringRange(of: range, in: rawInput) else { return rawInput }
        return rawInput.replacingCharacters(in: stringRange, with: replacement)
    }

    /// The substring a range addresses, or nil when the range does not fit.
    /// Used by tests and by the chip builder to sanity-check a range.
    static func substring(of range: RawTextRange, in rawInput: String) -> String? {
        guard let stringRange = stringRange(of: range, in: rawInput) else { return nil }
        return String(rawInput[stringRange])
    }

    private static func stringRange(
        of range: RawTextRange,
        in rawInput: String
    ) -> Range<String.Index>? {
        let characterCount = rawInput.count
        guard range.startOffset >= 0,
              range.endOffset <= characterCount,
              range.startOffset <= range.endOffset
        else { return nil }
        let start = rawInput.index(rawInput.startIndex, offsetBy: range.startOffset)
        let end = rawInput.index(rawInput.startIndex, offsetBy: range.endOffset)
        return start..<end
    }
}
