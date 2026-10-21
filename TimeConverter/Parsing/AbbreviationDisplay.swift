import Foundation

/// Editorial display metadata for a zone that the user named by an
/// **abbreviation** rather than by a place.
///
/// Backlog item 13 / spec amendment 2026-10-21: `12pm ET in London` must echo
/// as `12:00 pm Eastern Time (New York, Toronto, UTC-5) → …` rather than
/// silently substituting the identifier's city, which reads as though the user
/// had typed "New York". City- and country-resolved tokens carry no metadata and
/// echo exactly as before.
///
/// Hand-curated on purpose. Foundation has no "what do people call this zone"
/// data, and deriving a name from the identifier produces nonsense
/// (`America/Los_Angeles` → "Los Angeles Time"). Both tables are deliberately
/// small: only the abbreviations a person would actually type.
struct AbbreviationDisplay: Equatable, Sendable {
    /// The colloquial zone name, e.g. `Eastern Time`, `Central European Time`.
    let name: String
    /// One or two cities that stand for the zone, e.g. `["New York", "Toronto"]`.
    /// Two is the maximum by design — a longer list stops being a hint and
    /// starts being a table.
    let representativeCities: [String]

    init(name: String, representativeCities: [String]) {
        self.name = name
        self.representativeCities = representativeCities
    }

    /// `Eastern Time (New York, Toronto)` — the form used anywhere the offset
    /// is not also being rendered.
    var expandedDescription: String {
        guard !representativeCities.isEmpty else { return name }
        return "\(name) (\(representativeCities.joined(separator: ", ")))"
    }
}
