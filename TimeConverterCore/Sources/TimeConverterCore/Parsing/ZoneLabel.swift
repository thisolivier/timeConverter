import Foundation

/// How the result band names a zone — backlog item 21.
///
/// The key insight of the item is that the labelling is driven by **how the
/// token resolved**, not by the zone it resolved to. `America/New_York` is
/// `IN NEW YORK` when the user typed a city and `IN ET (EASTERN TIME)` when
/// they typed the code, because those are two different questions about the
/// same zone and echoing them identically loses the user's own words.
///
/// Only two cases, deliberately. The five resolvers collapse into "the user
/// named a place" and "the user named a code", and the device-local default
/// folds into the place case — see `ResolvedZone.zoneLabel`.
enum ZoneLabel: Equatable, Sendable {
    /// The user named a place (city, country, gazetteer entry) — or named
    /// nothing at all and got the device zone, which is still a place.
    case place(name: String, isDeviceLocal: Bool)

    /// The user named an abbreviation or a colloquial alias that the curated
    /// tables can expand. Both halves are shown, because the code is what was
    /// typed and the expansion is what it means.
    case abbreviation(code: String, expandedName: String)

    /// The header above the big time, in natural case:
    /// `In São Paulo`, `In Los Angeles (local)`, `In ET (Eastern Time)`.
    ///
    /// Natural case rather than shouted: uppercasing and letterspacing it is
    /// typography, and belongs to the view.
    var headerDescription: String {
        switch self {
        case let .place(name, isDeviceLocal):
            return isDeviceLocal ? "In \(name) (local)" : "In \(name)"
        case let .abbreviation(code, expandedName):
            return "In \(code) (\(expandedName))"
        }
    }
}

/// Renders the token the user typed back at them as a label.
///
/// The tokenizer lowercases everything, so `ET` arrives as `et` and has to be
/// re-cased before it can be shown. A code is all caps because that is how
/// codes are written; a multi-word colloquialism ("east coast") is title case
/// because `EAST COAST` in a sentence reads as shouting — the poster's own
/// uppercasing is a separate, typographic decision.
enum ZoneTokenDisplay {
    static func label(forToken token: String) -> String {
        guard token.contains(" ") else { return token.uppercased() }
        return token
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
