import Foundation

/// The three things the UI can be showing.
public enum ConverterDisplayState: Equatable, Sendable {
    /// Nothing to say: nothing typed yet, or a prompt is still being held back
    /// by the typing debounce (item 8). Both are the same quiet hint, and that
    /// is deliberate — showing a stale conversion under freshly edited text
    /// would be worse than showing nothing.
    case hint
    /// A successful conversion.
    case converted(ConverterDisplay)
    /// Any prompt — P1, P2, P4 or P5: the spec's message, plus the
    /// tap-to-replace chips that P4 and P5 can offer.
    case problem(ConverterProblem)

    /// The conversion, when there is one.
    ///
    /// Public because the redesigned iOS layout (item 18) draws one piece of
    /// the conversion — the source echo — *inside the input box*, far away from
    /// the `switch` that renders the result band. Reaching for it there is
    /// cheaper and clearer than threading the whole display state through two
    /// subviews.
    public var convertedDisplay: ConverterDisplay? {
        guard case let .converted(display) = self else { return nil }
        return display
    }
}

/// Pre-rendered strings for the output area, so the view holds no logic.
///
/// Two generations of fields live here side by side, on purpose.
///
/// `echoLine` and `detailLine` are the original one-sentence rendering: still
/// the spec's canonical echo, still what the Mac shell draws and what most of
/// the parsing tests assert against. The fields below them decompose the *same*
/// conversion into the slots the redesigned iOS layout needs (item 18) — a
/// source echo for inside the input box, a target place label, the time split
/// into poster-scale digits and a small meridiem, the zone line beneath them,
/// and the footer sentence. Nothing is computed twice: both generations come
/// off one `ConversionResult`.
///
/// The two generations also now disagree about UTC offsets, and that is the
/// point of item 21: the iOS slots dropped them (the result band says which
/// *zone*, and the chips are where an offset decides something), while
/// `echoLine` keeps them for the Mac shell, whose single sentence has nowhere
/// else to put them.
public struct ConverterDisplay: Equatable, Sendable {
    /// The spec's canonical echo:
    /// `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0) +1d`.
    public let echoLine: String
    /// Quieter supporting detail: the zones actually used, plus a note when the
    /// DST policy had to move the time.
    public let detailLine: String

    /// What the input box echoes back underneath the typed text:
    /// `Lisbon · 8:00 PM`. No UTC offset since item 21.
    public let sourceEchoLine: String
    /// The label above the result — `In São Paulo` for a place, or
    /// `In ET (Eastern Time)` when the user named a code (item 21). Natural
    /// case: uppercasing and letterspacing it is typography, which belongs to
    /// the view.
    public let targetPlaceLabel: String
    /// `4:00` — the design's poster-scale numerals.
    public let targetClockDigits: String
    /// `PM` — set smaller, on roughly the same baseline.
    public let targetMeridiem: String
    /// The line under the big time. Was the bare `UTC-3` the design drew;
    /// since item 21 it names the zone instead —
    /// `Brasilia Standard Time (São Paulo)` under a place header, or just
    /// `New York, Toronto` under a header that already expanded a code. The
    /// day-rollover note still rides here (`… · next day`), because the
    /// redesigned layout has no echo sentence to hang `+1d` off. Empty for GMT
    /// and UTC, which have no cities by design; the view draws nothing then.
    public let targetZoneLine: String
    /// The footer sentence: `4 hours behind Lisbon.`
    public let footerSentence: String
    /// The daylight-saving explanation, on the two days a year it applies.
    /// `nil` otherwise, which is the overwhelmingly common case.
    public let daylightSavingNote: String?
}

/// A prompt, ready to render: the message exactly as the spec words it, and
/// zero or more corrections the user can tap.
///
/// Structured rather than a bare `String` (which is what it was before items 7
/// and 9) so the view stays a `switch` with no logic in it — the chips arrive
/// already labelled, already carrying the edit they perform.
public struct ConverterProblem: Equatable, Sendable {
    public let message: String
    /// Empty for P1 and P2, which have no single token to rewrite.
    public let chips: [ReplacementChip]

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
public struct ReplacementChip: Equatable, Sendable, Identifiable {
    /// What the button says: `Chicago (UTC-6)` for an ambiguity, `London?` for
    /// a did-you-mean.
    public let label: String
    /// What gets written into the sentence.
    let replacementText: String
    /// The span of the raw input it replaces.
    let replacementRange: RawTextRange

    /// Stable within a row: the chips of one prompt all target the same range
    /// and differ by what they write.
    public var id: String {
        "\(replacementRange.startOffset)..<\(replacementRange.endOffset):\(replacementText)"
    }

    /// Applies this chip to the sentence the user typed.
    func applied(to rawInput: String) -> String {
        RawTextEditing.replacing(replacementRange, with: replacementText, in: rawInput)
    }
}
