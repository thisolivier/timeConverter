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

    /// The wall clock an injected instant shows in an injected zone — what a
    /// bare-zone input means by "now" (spec amendment 2026-10-23, item 22).
    ///
    /// Minutes are kept, not rounded: "ET" typed at 15:42 converts 15:42, since
    /// a time converter that quietly moved the user's clock to the hour would be
    /// lying. Still pure — both the instant and the zone are parameters, so the
    /// bare-zone tests are as deterministic as every other test here.
    static func wallClock(of instant: Date, in timeZone: TimeZone) -> ParsedTime {
        let components = GregorianCalendars.calendar(in: timeZone)
            .dateComponents([.hour, .minute], from: instant)
        return ParsedTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
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
    /// Not a resolver at all: the side the user didn't name, filled in from the
    /// device zone the caller injected (spec amendment 2026-10-22). No resolver
    /// ever produces this, which is exactly why it is worth distinguishing —
    /// the echo marks a defaulted side as `(local)`.
    case deviceLocalZone
}

/// How a split place name's picker names one of its zones (item 34b).
///
/// `portland` means Oregon or Maine, and a person who types it may not know
/// which coast's clock is which — so the chip says `Portland, Oregon`, not
/// `Los Angeles`. `typedForm` is what the tap writes into the sentence, and it
/// has to resolve to the same zone on its own (`Portland Oregon` is its own
/// gazetteer entry); `GazetteerCoverageTests` enforces that.
struct PlaceChoice: Equatable, Sendable {
    let label: String
    let typedForm: String
}

/// One possible meaning of a zone token, as emitted by a resolver.
struct ZoneCandidate: Equatable, Sendable {
    let timeZoneIdentifier: String
    let matchSource: ZoneMatchSource
    /// Set only by the two abbreviation resolvers, and only for abbreviations
    /// their curated tables cover. Everything else leaves it nil and keeps the
    /// identifier-derived city name (item 13).
    let abbreviationDisplay: AbbreviationDisplay?
    /// Set only by the gazetteer, and only for a split name that carries
    /// per-zone labels. Nil everywhere else, where the identifier's city is
    /// the right chip.
    let placeChoice: PlaceChoice?

    init(
        timeZoneIdentifier: String,
        matchSource: ZoneMatchSource,
        abbreviationDisplay: AbbreviationDisplay? = nil,
        placeChoice: PlaceChoice? = nil
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.matchSource = matchSource
        self.abbreviationDisplay = abbreviationDisplay
        self.placeChoice = placeChoice
    }

    /// City-style name derived from the identifier (`America/New_York` → `New
    /// York`), so the alias and country tables stay as plain identifier lists.
    /// This is what disambiguation pickers and chips show, because a chip's
    /// label has to be something the user can also type.
    var representativeCityName: String {
        ZoneDisplayName.forIdentifier(timeZoneIdentifier)
    }

    /// What a picker row for this candidate says — the place's own label when
    /// it has one, the identifier's city otherwise.
    var pickerLabel: String {
        placeChoice?.label ?? representativeCityName
    }

    /// What tapping that row writes into the sentence.
    var pickerTypedForm: String {
        placeChoice?.typedForm ?? representativeCityName
    }

    /// Name for the echo line: expanded for abbreviations, the plain city
    /// otherwise.
    var echoDisplayName: String {
        abbreviationDisplay?.name ?? representativeCityName
    }
}

/// A zone token that resolved to exactly one meaning.
struct ResolvedZone: Equatable, Sendable {
    let timeZone: TimeZone
    let displayName: String
    /// The curated metadata for the abbreviation the user typed, when they
    /// typed one the tables cover (item 13). `nil` for every place token — and
    /// also for an abbreviation Foundation knows but our tables do not, which
    /// is exactly the distinction item 21's labelling turns on. Stored rather
    /// than just its cities, because `zoneLabel` needs the expanded name too.
    let abbreviationDisplay: AbbreviationDisplay?
    let matchSource: ZoneMatchSource
    /// The token the user actually typed (normalised to lowercase), kept for
    /// echoing back and for prompt copy.
    let originalToken: String

    init(
        timeZone: TimeZone,
        displayName: String,
        abbreviationDisplay: AbbreviationDisplay? = nil,
        matchSource: ZoneMatchSource,
        originalToken: String
    ) {
        self.timeZone = timeZone
        self.displayName = displayName
        self.abbreviationDisplay = abbreviationDisplay
        self.matchSource = matchSource
        self.originalToken = originalToken
    }

    /// Cities to show beside `displayName` in the echo — populated only when
    /// the token resolved through an abbreviation the tables cover (item 13).
    var representativeCities: [String] {
        abbreviationDisplay?.representativeCities ?? []
    }

    /// How the result band names this zone (item 21).
    ///
    /// The whole rule, in one place: a curated abbreviation shows its code and
    /// its expansion, and *everything else* is a place — a typed city, a
    /// country, a gazetteer hit, an uncurated abbreviation that can only offer
    /// its identifier's city anyway, and the device-local default, which keeps
    /// its `(local)` marker rather than growing a third case.
    var zoneLabel: ZoneLabel {
        guard let abbreviationDisplay else {
            return .place(name: displayName, isDeviceLocal: isDeviceLocalZone)
        }
        return .abbreviation(
            code: ZoneTokenDisplay.label(forToken: originalToken),
            expandedName: abbreviationDisplay.name
        )
    }

    /// The injected device zone standing in for a side the user left unnamed
    /// ("7pm in London" names only the target, so the source is this).
    ///
    /// The zone arrives as a parameter — nothing in this module reads
    /// `TimeZone.current` — and the name is derived from the identifier, so a
    /// defaulted Los Angeles reads as `Los Angeles` exactly as the typed word
    /// would have.
    static func deviceLocal(_ timeZone: TimeZone) -> ResolvedZone {
        ResolvedZone(
            timeZone: timeZone,
            displayName: ZoneDisplayName.forIdentifier(timeZone.identifier),
            matchSource: .deviceLocalZone,
            // Nothing was typed, so there is no token to echo or to quote in
            // prompt copy.
            originalToken: ""
        )
    }

    /// True when this side was defaulted rather than named. Drives the echo's
    /// `(local)` marker, which is what makes the assumption visible.
    var isDeviceLocalZone: Bool { matchSource == .deviceLocalZone }
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
