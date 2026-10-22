import Foundation

/// One token a resolver is able to match, exposed purely so the did-you-mean
/// suggester (backlog item 9) can measure edit distances against it.
///
/// This is an *additive* capability: resolution itself still goes through
/// `candidates(for:)` and knows nothing about suggestions, so the parser stays
/// pure and a resolver that cannot enumerate its vocabulary simply offers none.
struct ZoneVocabularyEntry: Equatable, Sendable {
    /// What a token looks like, which is the only thing the suggester's
    /// editorial policy needs to know about it.
    enum Shape: Equatable, Sendable {
        /// A zone code: `et`, `cst`, `pst`, `gmt`. Short, opaque, and — fatally
        /// for naive suggestions — mutually one edit apart.
        case abbreviation
        /// A city or country name: `london`, `new york`, `portugal`.
        case placeName
    }

    /// The exact normalised token a user could type to hit this entry.
    let token: String
    let shape: Shape
    /// Which resolver owns it. Doubles as the chain-level tie-break when two
    /// levels offer the same distance.
    let matchSource: ZoneMatchSource

    /// Chip-facing form: abbreviations read as codes, places as names.
    var suggestionLabel: String {
        switch shape {
        case .abbreviation: return token.uppercased()
        case .placeName: return token.capitalized
        }
    }
}
