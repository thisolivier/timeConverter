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
        guard let identifiers = AliasZoneTable.identifiersByAlias[normalizedZoneToken] else {
            return []
        }
        return identifiers.map {
            ZoneCandidate(timeZoneIdentifier: $0, matchSource: matchSource)
        }
    }
}

/// Versioned in code on purpose: these are editorial choices (which city stands
/// for "ET", which meanings of "CST" we honour), not data to be scraped.
enum AliasZoneTable {
    static let identifiersByAlias: [String: [String]] = [
        // Ambiguous by design — every listed meaning is offered to the user.
        "cst": ["America/Chicago", "Asia/Shanghai"],
        "ist": ["Asia/Kolkata", "Europe/Dublin"],

        // DST-neutral North American forms. Foundation only knows the
        // standard/daylight variants (EST/EDT), not the plain ones people type.
        "et": ["America/New_York"],
        "ct": ["America/Chicago"],
        "mt": ["America/Denver"],
        "pt": ["America/Los_Angeles"],
        "akt": ["America/Anchorage"],
        "nyc": ["America/New_York"],

        // European colloquialisms.
        "uk": ["Europe/London"],
        "gb": ["Europe/London"],
        "cet": ["Europe/Paris"],
        "cest": ["Europe/Paris"],
        "eet": ["Europe/Athens"],
        "eest": ["Europe/Athens"],
        "wet": ["Europe/Lisbon"],
        "west": ["Europe/Lisbon"],

        // Australian forms, none of which Foundation knows.
        "aet": ["Australia/Sydney"],
        "aest": ["Australia/Sydney"],
        "aedt": ["Australia/Sydney"],
        "acst": ["Australia/Adelaide"],
        "acdt": ["Australia/Adelaide"],
        "awst": ["Australia/Perth"],
    ]
}
