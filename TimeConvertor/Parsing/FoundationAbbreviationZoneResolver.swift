import Foundation

/// Step 2 — `TimeZone.abbreviationDictionary` (PST, EST, GMT, JST, …).
///
/// Free coverage of the unambiguous abbreviations, so the hand-rolled table
/// above only has to carry what Foundation gets wrong or misses. The dictionary
/// is keyed by uppercase abbreviation and never contains spaces, so multi-word
/// tokens fall through to the city and country resolvers naturally.
struct FoundationAbbreviationZoneResolver: ZoneResolver {
    let matchSource: ZoneMatchSource = .foundationAbbreviation

    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate] {
        guard let identifier = TimeZone.abbreviationDictionary[normalizedZoneToken.uppercased()]
        else { return [] }
        return [ZoneCandidate(timeZoneIdentifier: identifier, matchSource: matchSource)]
    }
}
