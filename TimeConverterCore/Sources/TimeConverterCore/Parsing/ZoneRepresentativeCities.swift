import Foundation

/// Which two or three cities stand for a zone — backlog item 21's sub-line.
///
/// A place-resolved target shows its zone's *name* plus the cities that make
/// that name concrete: `Brasilia Standard Time (São Paulo)`. The cities come
/// from the two abbreviation tables we already curate, read backwards: those
/// tables answer "which cities stand for ET", and this index answers "which
/// cities stand for `America/New_York`", which is the same editorial judgement
/// pointing the other way. No second table to keep in sync.
///
/// ## The self-consistency rule
///
/// An entry is accepted for a zone only when the zone's **own** city appears in
/// the list. Without that rule the index inherits the abbreviation tables' loose
/// ends: Foundation maps `MST` to `America/Phoenix`, whose curated cities are
/// Denver and Calgary, so Phoenix — the one US zone that does not observe
/// daylight saving — would be labelled with two cities that do. The rule
/// rejects exactly those entries and lets them fall back to the identifier's
/// own city, which is never wrong.
enum ZoneRepresentativeCities {
    /// The design shows two; three is the ceiling before the parenthetical
    /// stops being a hint and becomes a list.
    static let maximumCityCount = 3

    /// The cities for a zone: the curated list when there is a self-consistent
    /// one, otherwise the identifier's own city on its own.
    ///
    /// Never empty, which is what lets the sub-line always have something
    /// concrete to say about a place.
    static func cities(forIdentifier timeZoneIdentifier: String) -> [String] {
        guard let curated = curatedCitiesByIdentifier[timeZoneIdentifier] else {
            return [ZoneDisplayName.forIdentifier(timeZoneIdentifier)]
        }
        return Array(curated.prefix(maximumCityCount))
    }

    /// Built once from both abbreviation tables.
    ///
    /// Walked in sorted-key order with the alias table first, and a richer list
    /// beats a shorter one — so Sydney gets Sydney *and* Melbourne from `aest`
    /// rather than whichever of `aet`/`aest`/`aedt` a dictionary happened to
    /// yield first. Determinism matters here: an unordered walk would make the
    /// sub-line differ between runs.
    static let curatedCitiesByIdentifier: [String: [String]] = {
        var citiesByIdentifier: [String: [String]] = [:]
        for (timeZoneIdentifier, cities) in curatedEntries {
            guard !cities.isEmpty else { continue }
            guard isSelfConsistent(cities: cities, for: timeZoneIdentifier) else { continue }
            let existingCount = citiesByIdentifier[timeZoneIdentifier]?.count ?? 0
            guard cities.count > existingCount else { continue }
            citiesByIdentifier[timeZoneIdentifier] = cities
        }
        return citiesByIdentifier
    }()

    /// Every (identifier, cities) pair the two tables assert, in a fixed order.
    private static var curatedEntries: [(String, [String])] {
        let aliasEntries = AliasZoneTable.meaningsByAlias.keys.sorted().flatMap { alias in
            (AliasZoneTable.meaningsByAlias[alias] ?? []).map {
                ($0.timeZoneIdentifier, $0.display.representativeCities)
            }
        }
        let foundationEntries = FoundationAbbreviationDisplayTable
            .displaysByAbbreviation.keys.sorted()
            .compactMap { abbreviation -> (String, [String])? in
                guard let identifier = TimeZone.abbreviationDictionary[abbreviation],
                      let display = FoundationAbbreviationDisplayTable
                          .displaysByAbbreviation[abbreviation]
                else { return nil }
                return (identifier, display.representativeCities)
            }
        return aliasEntries + foundationEntries
    }

    /// True when the zone's own city is one of the listed cities.
    ///
    /// Compared diacritic-insensitively because the tables spell `São Paulo`
    /// properly while the identifier can only ever yield `Sao Paulo`, and the
    /// accented spelling is the one worth showing.
    static func isSelfConsistent(cities: [String], for timeZoneIdentifier: String) -> Bool {
        let ownCity = comparable(ZoneDisplayName.forIdentifier(timeZoneIdentifier))
        return cities.contains { comparable($0) == ownCity }
    }

    private static func comparable(_ cityName: String) -> String {
        cityName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
