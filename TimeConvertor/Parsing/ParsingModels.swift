import Foundation

/// Value types shared by the parser, the resolver chain and the conversion
/// engine. Everything here is a pure value with no clock or UI access, so the
/// whole parsing pipeline is deterministic and unit-testable.

// MARK: - Time

/// A wall-clock time of day with no date and no zone attached.
///
/// Always normalised to a 24-hour representation: `12 am` becomes hour 0 and
/// `12 pm` becomes hour 12, per the spec's midnight/noon convention.
struct ParsedTime: Equatable, Sendable {
    /// 0...23.
    let hour: Int
    /// 0...59.
    let minute: Int

    /// Canonical echo form, always 12-hour with a space before the meridiem
    /// (`12:00 pm`, `5:00 pm`) — the form the spec's output examples use.
    var canonicalDescription: String {
        TimeFormatting.twelveHourDescription(hour: hour, minute: minute)
    }
}

// MARK: - Zones

/// Which half of the input a zone token came from. Prompts carry this so the UI
/// can highlight the offending side.
enum ZoneSide: String, Equatable, Sendable {
    case source
    case target
}

/// The conjunction that split the input. Closed list, per the grammar.
enum Conjunction: String, Equatable, Sendable, CaseIterable {
    case inWord = "in"
    case toWord = "to"
}

/// Which resolver in the ordered chain produced a candidate. Kept on results so
/// tests (and later, diagnostics) can assert *how* a token resolved, not just
/// that it did.
enum ZoneMatchSource: String, Equatable, Sendable {
    case aliasTable
    case foundationAbbreviation
    case timeZoneDatabaseCity
    case countryTable
    case offlineFallbackList
}

/// One possible meaning of a zone token, as emitted by a resolver.
struct ZoneCandidate: Equatable, Sendable {
    let timeZoneIdentifier: String
    let matchSource: ZoneMatchSource

    /// Human-facing name derived from the identifier, so the alias and country
    /// tables stay as plain identifier lists with no duplicated display copy.
    var displayName: String {
        ZoneDisplayName.forIdentifier(timeZoneIdentifier)
    }
}

/// A zone token that resolved to exactly one meaning.
struct ResolvedZone: Equatable, Sendable {
    let timeZone: TimeZone
    let displayName: String
    let matchSource: ZoneMatchSource
    /// The token the user actually typed (normalised to lowercase), kept for
    /// echoing back and for prompt copy.
    let originalToken: String
}

// MARK: - Requests and outcomes

/// A fully resolved conversion, ready for `ConversionEngine`.
///
/// Carries its own reference date so the engine never touches the clock: the
/// caller injects the device's current `Date` once, at parse time.
struct ConversionRequest: Equatable, Sendable {
    let time: ParsedTime
    let sourceZone: ResolvedZone
    let targetZone: ResolvedZone
    /// "Now" as supplied by the caller. The time of day is interpreted as
    /// *today* in the source zone, where "today" is this date read in that zone.
    let referenceDate: Date
}

/// The only two things parsing can produce: a conversion to run, or a prompt to
/// put in front of the user.
enum ParseOutcome: Equatable, Sendable {
    case request(ConversionRequest)
    case prompt(Prompt)
}

// MARK: - Prompts

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
    case ambiguousZone(token: String, side: ZoneSide, choices: [ZoneChoice])

    /// P5 — no resolver in the chain recognised the token.
    case unknownZone(token: String, side: ZoneSide)

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
