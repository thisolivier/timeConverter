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
        let abbreviation = normalizedZoneToken.uppercased()
        guard let identifier = TimeZone.abbreviationDictionary[abbreviation] else { return [] }
        return [ZoneCandidate(
            timeZoneIdentifier: identifier,
            matchSource: matchSource,
            abbreviationDisplay: FoundationAbbreviationDisplayTable
                .displaysByAbbreviation[abbreviation]
        )]
    }

    /// Foundation's dictionary is enumerable, so the whole of step 2 is
    /// vocabulary — all of it abbreviation-shaped, which is what keeps the
    /// suggester from offering `cet` when the user mistyped a neighbouring code.
    var vocabulary: [ZoneVocabularyEntry] {
        TimeZone.abbreviationDictionary.keys.map {
            ZoneVocabularyEntry(
                token: $0.lowercased(),
                shape: .abbreviation,
                matchSource: matchSource
            )
        }
    }
}

/// Expanded names for the Foundation abbreviations worth expanding (item 13).
///
/// Hand-curated and deliberately short. Foundation knows ~400 abbreviations,
/// most of which nobody types and several of which have no agreed English name;
/// deriving names algorithmically from the identifier produces things like
/// "Los Angeles Time". An abbreviation absent from this table echoes as its
/// identifier's city, exactly as before — a quiet, correct fallback.
///
/// Keys are uppercase, matching Foundation's dictionary.
enum FoundationAbbreviationDisplayTable {
    static let displaysByAbbreviation: [String: AbbreviationDisplay] = [
        // North America. The standard/daylight pair is kept distinct because
        // the user chose to be specific by typing it.
        "EST": AbbreviationDisplay(
            name: "Eastern Standard Time", representativeCities: ["New York", "Toronto"]
        ),
        "EDT": AbbreviationDisplay(
            name: "Eastern Daylight Time", representativeCities: ["New York", "Toronto"]
        ),
        "CDT": AbbreviationDisplay(
            name: "Central Daylight Time", representativeCities: ["Chicago", "Dallas"]
        ),
        "MST": AbbreviationDisplay(
            name: "Mountain Standard Time", representativeCities: ["Denver", "Calgary"]
        ),
        "MDT": AbbreviationDisplay(
            name: "Mountain Daylight Time", representativeCities: ["Denver", "Calgary"]
        ),
        "PST": AbbreviationDisplay(
            name: "Pacific Standard Time", representativeCities: ["Los Angeles", "Vancouver"]
        ),
        "PDT": AbbreviationDisplay(
            name: "Pacific Daylight Time", representativeCities: ["Los Angeles", "Vancouver"]
        ),
        "AKST": AbbreviationDisplay(
            name: "Alaska Standard Time", representativeCities: ["Anchorage"]
        ),
        "AKDT": AbbreviationDisplay(
            name: "Alaska Daylight Time", representativeCities: ["Anchorage"]
        ),
        "HST": AbbreviationDisplay(
            name: "Hawaii Standard Time", representativeCities: ["Honolulu"]
        ),
        "AST": AbbreviationDisplay(
            name: "Atlantic Standard Time", representativeCities: ["Halifax"]
        ),
        "ADT": AbbreviationDisplay(
            name: "Atlantic Daylight Time", representativeCities: ["Halifax"]
        ),

        // Europe. No cities for GMT/UTC: they are the reference, not a place.
        "GMT": AbbreviationDisplay(name: "Greenwich Mean Time", representativeCities: []),
        "UTC": AbbreviationDisplay(name: "Coordinated Universal Time", representativeCities: []),
        "BST": AbbreviationDisplay(
            name: "British Summer Time", representativeCities: ["London"]
        ),
        "WEST": AbbreviationDisplay(
            name: "Western European Summer Time", representativeCities: ["Lisbon"]
        ),

        // Asia and the Pacific.
        "JST": AbbreviationDisplay(name: "Japan Standard Time", representativeCities: ["Tokyo"]),
        "KST": AbbreviationDisplay(name: "Korea Standard Time", representativeCities: ["Seoul"]),
        "HKT": AbbreviationDisplay(name: "Hong Kong Time", representativeCities: ["Hong Kong"]),
        "SGT": AbbreviationDisplay(
            name: "Singapore Time", representativeCities: ["Singapore"]
        ),
        "NZST": AbbreviationDisplay(
            name: "New Zealand Standard Time", representativeCities: ["Auckland"]
        ),
        "NZDT": AbbreviationDisplay(
            name: "New Zealand Daylight Time", representativeCities: ["Auckland"]
        ),

        // South America.
        "BRT": AbbreviationDisplay(name: "Brasília Time", representativeCities: ["São Paulo"]),
        "ART": AbbreviationDisplay(
            name: "Argentina Time", representativeCities: ["Buenos Aires"]
        ),
    ]
}
