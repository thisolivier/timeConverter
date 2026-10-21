import Foundation

/// The spec's five disambiguation prompts, as values.
///
/// Prompts are data, not UI: the parser emits them and the presenter renders
/// them, which is what keeps every prompt trigger unit-testable. The spec's
/// wording lives in `PromptMessages.swift`.

/// One candidate as offered in a disambiguation picker (P4), pre-rendered with
/// the detail the spec asks for: a representative city and the current UTC
/// offset at the injected reference date.
struct ZoneChoice: Equatable, Sendable {
    let timeZoneIdentifier: String
    let representativeCity: String
    let utcOffsetDescription: String
}

/// The five prompts from the spec, as values. Item 4 renders these; the parser
/// never formats UI itself (though `message` offers the spec's copy for
/// convenience, see `PromptMessages.swift`).
enum Prompt: Equatable, Sendable {
    /// P1 — no parseable time at the start of the input.
    case timeNotFound(input: String)

    /// P2 — a time was found but no source zone precedes the conjunction.
    /// `conjunction` is nil when the user hasn't typed one yet at all.
    case missingSourceZone(time: ParsedTime, conjunction: Conjunction?)

    /// P3 — no conjunction found, or nothing after it.
    case missingTargetZone(time: ParsedTime, sourceZoneToken: String)

    /// P4 — the token has more than one meaning. Never silently defaulted.
    /// `tokenRange` addresses the token inside the raw input so the UI can
    /// offer chips that rewrite it in place.
    case ambiguousZone(
        token: String,
        side: ZoneSide,
        tokenRange: RawTextRange,
        choices: [ZoneChoice]
    )

    /// P5 — no resolver in the chain recognised the token. Carries the same
    /// rewrite range as P4, for did-you-mean chips.
    case unknownZone(token: String, side: ZoneSide, tokenRange: RawTextRange)

    /// Where in the raw input the offending zone token sits, for the prompts
    /// that offer a tap-to-replace correction. Nil for P1–P3, which have no
    /// single token to rewrite.
    var offendingTokenRange: RawTextRange? {
        switch self {
        case let .ambiguousZone(_, _, tokenRange, _): return tokenRange
        case let .unknownZone(_, _, tokenRange): return tokenRange
        default: return nil
        }
    }

    /// Stable identifier matching the spec's prompt table, for tests and
    /// analytics.
    var specIdentifier: String {
        switch self {
        case .timeNotFound: return "P1"
        case .missingSourceZone: return "P2"
        case .missingTargetZone: return "P3"
        case .ambiguousZone: return "P4"
        case .unknownZone: return "P5"
        }
    }
}
