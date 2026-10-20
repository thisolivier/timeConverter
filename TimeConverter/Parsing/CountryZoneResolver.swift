import Foundation

/// Step 4 — the hand-rolled country table.
///
/// Countries with a national clock resolve to exactly one zone, whether they
/// span one (`japan` → `Asia/Tokyo`) or several (`portugal` → `Europe/Lisbon`,
/// not Azores). Countries with no single national clock return every zone,
/// which the chain turns into a picker: `usa` → the six primary US zones.
struct CountryZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .countryTable

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let zones = CountryZoneTable.zonesByCountryName[normalizedZoneToken] else {
            return []
        }
        return zones.candidateIdentifiers.map {
            ZoneCandidate(timeZoneIdentifier: $0, matchSource: matchSource)
        }
    }
}
