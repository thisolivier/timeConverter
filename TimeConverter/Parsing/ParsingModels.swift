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
    /// Set only by the two abbreviation resolvers, and only for abbreviations
    /// their curated tables cover. Everything else leaves it nil and keeps the
    /// identifier-derived city name (item 13).
    let abbreviationDisplay: AbbreviationDisplay?

    init(
        timeZoneIdentifier: String,
        matchSource: ZoneMatchSource,
        abbreviationDisplay: AbbreviationDisplay? = nil
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.matchSource = matchSource
        self.abbreviationDisplay = abbreviationDisplay
    }

    /// City-style name derived from the identifier (`America/New_York` → `New
    /// York`), so the alias and country tables stay as plain identifier lists.
    /// This is what disambiguation pickers and chips show, because a chip's
    /// label has to be something the user can also type.
    var representativeCityName: String {
        ZoneDisplayName.forIdentifier(timeZoneIdentifier)
    }

    /// Name for the echo line: expanded for abbreviations, the plain city
    /// otherwise.
    var echoDisplayName: String {
        abbreviationDisplay?.name ?? representativeCityName
    }

    /// Extra cities the echo line should show beside `echoDisplayName`. Empty
    /// for city and country tokens, which already *are* a place name.
    var echoRepresentativeCities: [String] {
        abbreviationDisplay?.representativeCities ?? []
    }
}

/// A zone token that resolved to exactly one meaning.
struct ResolvedZone: Equatable, Sendable {
    let timeZone: TimeZone
    let displayName: String
    /// Cities to show beside `displayName` in the echo — populated only when
    /// the token resolved through an abbreviation (item 13).
    let representativeCities: [String]
    let matchSource: ZoneMatchSource
    /// The token the user actually typed (normalised to lowercase), kept for
    /// echoing back and for prompt copy.
    let originalToken: String

    init(
        timeZone: TimeZone,
        displayName: String,
        representativeCities: [String] = [],
        matchSource: ZoneMatchSource,
        originalToken: String
    ) {
        self.timeZone = timeZone
        self.displayName = displayName
        self.representativeCities = representativeCities
        self.matchSource = matchSource
        self.originalToken = originalToken
    }
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
