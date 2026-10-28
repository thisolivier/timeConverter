import Foundation

/// A starred destination (backlog item 30): the zone the converter resolved,
/// plus the label the user asked for it with.
///
/// The label is part of the identity on purpose. Starring `New York` and
/// starring `ET` are two favourites with one identifier: the world clock keeps
/// the user's own word for each, exactly as item 21's result band does.
public struct FavouriteDestination: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let timeZoneIdentifier: String
    public let label: ZoneLabel

    public init(timeZoneIdentifier: String, label: ZoneLabel) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.label = label
    }

    /// Stable across launches and unique per (identifier, label) pair:
    /// `Europe/London|place:London`, `America/New_York|code:ET:Eastern Time`.
    public var id: String {
        switch label {
        case let .place(name, isDeviceLocal):
            return "\(timeZoneIdentifier)|place:\(name)\(isDeviceLocal ? ":local" : "")"
        case let .abbreviation(code, expandedName):
            return "\(timeZoneIdentifier)|code:\(code):\(expandedName)"
        }
    }
}

extension FavouriteDestination {
    /// The zone as the converter would have resolved it, so the world clock
    /// can run the very same `ConversionEngine` path. `nil` only for an
    /// identifier this OS no longer knows, which the clock then skips.
    ///
    /// A code label recovers its curated cities by asking the resolver chain
    /// the same question again (`ET` → New York, Toronto), so the zone line
    /// reads exactly as it did on the result band. The stored expansion stays
    /// authoritative for the label itself.
    var resolvedZone: ResolvedZone? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        switch label {
        case let .place(name, _):
            return ResolvedZone(
                timeZone: timeZone,
                displayName: name,
                matchSource: .timeZoneDatabaseCity,
                originalToken: name.lowercased()
            )
        case let .abbreviation(code, expandedName):
            let curatedCities = Self.curatedCities(forCode: code, identifier: timeZoneIdentifier)
            return ResolvedZone(
                timeZone: timeZone,
                displayName: expandedName,
                abbreviationDisplay: AbbreviationDisplay(
                    name: expandedName, representativeCities: curatedCities
                ),
                matchSource: .aliasTable,
                originalToken: code.lowercased()
            )
        }
    }

    private static func curatedCities(forCode code: String, identifier: String) -> [String] {
        switch ZoneResolverChain.standard.resolve(code.lowercased()) {
        case let .resolved(zone) where zone.timeZone.identifier == identifier:
            return zone.representativeCities
        case let .ambiguous(candidates):
            return candidates
                .first { $0.timeZoneIdentifier == identifier }?
                .abbreviationDisplay?.representativeCities ?? []
        default:
            return []
        }
    }

    /// What starring the target of `12pm in <typedZone>` would store, or `nil`
    /// when that sentence does not convert (unknown or ambiguous zone).
    ///
    /// Used by the DEBUG `-favourites` seed and by the fixture catalog, so both
    /// produce exactly the label a real tap on the star would.
    static func resolvingTypedZone(_ typedZone: String) -> FavouriteDestination? {
        let anyFixedInstant = Date(timeIntervalSince1970: 1_768_478_400)
        let utc = TimeZone(secondsFromGMT: 0)!
        guard case let .result(result) = InputParser()
            .parseAndConvert("12pm in \(typedZone)", now: anyFixedInstant, localZone: utc)
        else { return nil }
        return FavouriteDestination(converterTarget: result.target)
    }

    /// The favourite a conversion's target would make, or `nil` for a target
    /// defaulted to the device zone: the local clock is always the world
    /// clock's first row anyway, so `(local)` cannot be starred.
    init?(converterTarget target: ZoneReading) {
        guard !target.isDeviceLocalZone else { return nil }
        self.init(timeZoneIdentifier: target.timeZoneIdentifier, label: target.zoneLabel)
    }
}
