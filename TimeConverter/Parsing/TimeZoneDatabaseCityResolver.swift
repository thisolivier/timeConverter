import Foundation

/// Step 3 — city match against the tz database itself.
///
/// Indexes the final path component of every *area-prefixed*
/// `TimeZone.knownTimeZoneIdentifiers` entry with underscores turned into
/// spaces, which is what makes multi-word cities work for free:
/// `new york` → `America/New_York`.
///
/// Only identifiers under a canonical IANA area are indexed. That is the
/// spec's step-3 guard: depending on OS version the known list may also carry
/// legacy backward-compatibility names — bare country names (`Portugal`,
/// `Japan`, `GB`), region-prefixed aliases (`US/Pacific`, `Canada/Eastern`)
/// and `Etc/*` offsets. Indexing those would let `portugal` short-circuit here
/// and bypass the country table's canonical/prompt policy, so an allow-list of
/// real areas keeps country handling where it belongs, in step 4.
///
/// The index maps to *arrays* even though the current tz db has no colliding
/// final components — if a future release introduces one, the chain already
/// treats it as an ambiguity and prompts instead of silently preferring
/// whichever came first.
struct TimeZoneDatabaseCityResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .timeZoneDatabaseCity

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let identifiers = Self.identifiersByCityName[normalizedZoneToken] else { return [] }
        return identifiers.map {
            ZoneCandidate(timeZoneIdentifier: $0, matchSource: matchSource)
        }
    }

    /// The indexed city names. The richest vocabulary the suggester has (~400
    /// entries) and the one it most wants to offer — a mistyped city is the
    /// failure mode item 9 exists for.
    var vocabulary: [ZoneVocabularyEntry] {
        Self.identifiersByCityName.keys.map {
            ZoneVocabularyEntry(token: $0, shape: .placeName, matchSource: matchSource)
        }
    }

    /// The canonical IANA areas. Everything else in the known list is a legacy
    /// alias or a synthetic offset bucket, and is not a city.
    static let cityBearingAreas: Set<String> = [
        "Africa", "America", "Antarctica", "Arctic", "Asia",
        "Atlantic", "Australia", "Europe", "Indian", "Pacific",
    ]

    /// Built once, lazily, from whatever tz database the OS ships.
    static let identifiersByCityName: [String: [String]] = {
        var index: [String: [String]] = [:]
        for identifier in TimeZone.knownTimeZoneIdentifiers where isCityBearing(identifier) {
            let cityName = ZoneDisplayName.forIdentifier(identifier).lowercased()
            index[cityName, default: []].append(identifier)
        }
        return index.mapValues { $0.sorted() }
    }()

    /// An identifier names a city only if it is area-prefixed (`Europe/London`)
    /// and the area is a real one. Bare names have no `/` at all; `US/Pacific`
    /// and `Etc/GMT+5` have one but not a city area.
    static func isCityBearing(_ identifier: String) -> Bool {
        let components = identifier.split(separator: "/")
        guard components.count >= 2 else { return false }
        return cityBearingAreas.contains(String(components[0]))
    }
}
