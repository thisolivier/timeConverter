import Foundation

/// The three things the UI can be showing.
enum ConverterDisplayState: Equatable, Sendable {
    /// Nothing to say: nothing typed yet, or a prompt is still being held back
    /// by the typing debounce (item 8). Both are the same quiet hint, and that
    /// is deliberate — showing a stale conversion under freshly edited text
    /// would be worse than showing nothing.
    case hint
    /// A successful conversion.
    case converted(ConverterDisplay)
    /// Any of P1–P5: the spec's message, plus the tap-to-replace chips that
    /// P4 and P5 can offer.
    case problem(ConverterProblem)
}

/// Pre-rendered strings for the output area, so the view holds no logic.
struct ConverterDisplay: Equatable, Sendable {
    /// The spec's canonical echo:
    /// `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0) +1d`.
    let echoLine: String
    /// Quieter supporting detail: the zones actually used, plus a note when the
    /// DST policy had to move the time.
    let detailLine: String
}

/// A prompt, ready to render: the message exactly as the spec words it, and
/// zero or more corrections the user can tap.
///
/// Structured rather than a bare `String` (which is what it was before items 7
/// and 9) so the view stays a `switch` with no logic in it — the chips arrive
/// already labelled, already carrying the edit they perform.
struct ConverterProblem: Equatable, Sendable {
    let message: String
    /// Empty for P1–P3, which have no single token to rewrite.
    let chips: [ReplacementChip]

    init(message: String, chips: [ReplacementChip] = []) {
        self.message = message
        self.chips = chips
    }
}

/// One tap-to-replace button under a prompt.
///
/// The guiding rule of the UI is that the typed sentence is the single source
/// of truth, so a chip does not hold a parallel selection — it rewrites a span
/// of the input string and lets the ordinary re-parse take it from there. That
/// is why it carries a `RawTextRange` and not an identifier.
struct ReplacementChip: Equatable, Sendable, Identifiable {
    /// What the button says: `Chicago (UTC-6)` for an ambiguity, `London?` for
    /// a did-you-mean.
    let label: String
    /// What gets written into the sentence.
    let replacementText: String
    /// The span of the raw input it replaces.
    let replacementRange: RawTextRange

    /// Stable within a row: the chips of one prompt all target the same range
    /// and differ by what they write.
    var id: String {
        "\(replacementRange.startOffset)..<\(replacementRange.endOffset):\(replacementText)"
    }

    /// Applies this chip to the sentence the user typed.
    func applied(to rawInput: String) -> String {
        RawTextEditing.replacing(replacementRange, with: replacementText, in: rawInput)
    }
}
