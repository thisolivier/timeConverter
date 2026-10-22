import Foundation

/// Step 1 — the hand-rolled alias table.
///
/// Covers the DST-neutral and colloquial abbreviations Foundation's
/// `abbreviationDictionary` has no entry for (`ET`, `PT`, `CT`, `MT`, `UK`,
/// `AEST`…), and deliberately *overrides* Foundation for abbreviations that
/// genuinely mean two different places. `CST` and `IST` both resolve to a
/// single zone in Foundation; listing both meanings here means the user gets a
/// picker instead of a silent guess.
struct AliasZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .aliasTable

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let meanings = AliasZoneTable.meaningsByAlias[normalizedZoneToken] else {
            return []
        }
        return meanings.map {
            ZoneCandidate(
                timeZoneIdentifier: $0.timeZoneIdentifier,
                matchSource: matchSource,
                abbreviationDisplay: $0.display
            )
        }
    }

    /// Nearly every alias is a zone code, so the suggester treats the table as
    /// abbreviation vocabulary — see `ZoneSuggestionEngine`'s policy. The
    /// multi-word colloquialisms ("east coast") are the exception: they are
    /// phrases, long enough for edit distance to mean something, and a chip
    /// labelled `EAST COAST` would read as shouting. Shape affects only
    /// labelling and ranking, never resolution.
    var vocabulary: [ZoneVocabularyEntry] {
        AliasZoneTable.meaningsByAlias.keys.map { alias in
            ZoneVocabularyEntry(
                token: alias,
                shape: alias.contains(" ") ? .placeName : .abbreviation,
                matchSource: matchSource
            )
        }
    }
}

/// One meaning of an alias: the zone, plus the expanded name the echo shows
/// (item 13). Positional initialiser so the table below reads as a table.
struct AliasZoneMeaning: Equatable, Sendable {
    let timeZoneIdentifier: String
    let display: AbbreviationDisplay

    init(_ timeZoneIdentifier: String, _ name: String, _ representativeCities: [String]) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.display = AbbreviationDisplay(name: name, representativeCities: representativeCities)
    }
}

/// Versioned in code on purpose: these are editorial choices (which city stands
/// for "ET", which meanings of "CST" we honour, what to *call* each one), not
/// data to be scraped.
enum AliasZoneTable {
    static let meaningsByAlias: [String: [AliasZoneMeaning]] = [
        // Ambiguous by design — every listed meaning is offered to the user,
        // and the two meanings of CST get their own names rather than sharing a
        // vague one.
        "cst": [
            AliasZoneMeaning("America/Chicago", "Central Time", ["Chicago", "Dallas"]),
            AliasZoneMeaning("Asia/Shanghai", "China Standard Time", ["Shanghai", "Beijing"]),
        ],
        "ist": [
            AliasZoneMeaning("Asia/Kolkata", "India Standard Time", ["Kolkata", "Mumbai"]),
            AliasZoneMeaning("Europe/Dublin", "Irish Standard Time", ["Dublin"]),
        ],

        // DST-neutral North American forms. Foundation only knows the
        // standard/daylight variants (EST/EDT), not the plain ones people type.
        "et": [AliasZoneMeaning("America/New_York", "Eastern Time", ["New York", "Toronto"])],
        "ct": [AliasZoneMeaning("America/Chicago", "Central Time", ["Chicago", "Dallas"])],
        "mt": [AliasZoneMeaning("America/Denver", "Mountain Time", ["Denver", "Calgary"])],
        "pt": [
            AliasZoneMeaning(
                "America/Los_Angeles", "Pacific Time", ["Los Angeles", "Vancouver"]
            ),
        ],
        "akt": [AliasZoneMeaning("America/Anchorage", "Alaska Time", ["Anchorage"])],
        "nyc": [AliasZoneMeaning("America/New_York", "Eastern Time", ["New York"])],

        // Colloquial US coasts — multi-word entries, and the spec's own example
        // of a single-zone input ("7pm East Coast"). Each maps to the
        // DST-neutral zone a person on that coast means, and echoes with the
        // same expanded name as its code equivalent (`et`, `pt`).
        "east coast": [
            AliasZoneMeaning("America/New_York", "Eastern Time", ["New York", "Toronto"]),
        ],
        "west coast": [
            AliasZoneMeaning(
                "America/Los_Angeles", "Pacific Time", ["Los Angeles", "Vancouver"]
            ),
        ],

        // European colloquialisms.
        "uk": [AliasZoneMeaning("Europe/London", "UK Time", ["London"])],
        "gb": [AliasZoneMeaning("Europe/London", "UK Time", ["London"])],
        "cet": [
            AliasZoneMeaning("Europe/Paris", "Central European Time", ["Paris", "Berlin"]),
        ],
        "cest": [
            AliasZoneMeaning("Europe/Paris", "Central European Summer Time", ["Paris", "Berlin"]),
        ],
        "eet": [
            AliasZoneMeaning("Europe/Athens", "Eastern European Time", ["Athens", "Helsinki"]),
        ],
        "eest": [
            AliasZoneMeaning(
                "Europe/Athens", "Eastern European Summer Time", ["Athens", "Helsinki"]
            ),
        ],
        "wet": [
            AliasZoneMeaning("Europe/Lisbon", "Western European Time", ["Lisbon"]),
        ],
        "west": [
            AliasZoneMeaning("Europe/Lisbon", "Western European Summer Time", ["Lisbon"]),
        ],

        // Australian forms, none of which Foundation knows.
        "aet": [AliasZoneMeaning("Australia/Sydney", "Australian Eastern Time", ["Sydney"])],
        "aest": [
            AliasZoneMeaning(
                "Australia/Sydney", "Australian Eastern Standard Time", ["Sydney", "Melbourne"]
            ),
        ],
        "aedt": [
            AliasZoneMeaning(
                "Australia/Sydney", "Australian Eastern Daylight Time", ["Sydney", "Melbourne"]
            ),
        ],
        "acst": [
            AliasZoneMeaning(
                "Australia/Adelaide", "Australian Central Standard Time", ["Adelaide"]
            ),
        ],
        "acdt": [
            AliasZoneMeaning(
                "Australia/Adelaide", "Australian Central Daylight Time", ["Adelaide"]
            ),
        ],
        "awst": [
            AliasZoneMeaning("Australia/Perth", "Australian Western Standard Time", ["Perth"]),
        ],
    ]

    /// The identifiers only, which is all the integrity tests and any
    /// identifier-level caller need.
    static var identifiersByAlias: [String: [String]] {
        meaningsByAlias.mapValues { $0.map(\.timeZoneIdentifier) }
    }
}
