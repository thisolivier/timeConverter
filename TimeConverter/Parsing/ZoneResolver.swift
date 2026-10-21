import Foundation

/// One step in the zone-resolution chain. Each resolver answers a token with
/// zero or more candidate meanings; the chain stops at the first resolver that
/// returns at least one.
///
/// The protocol exists so the ordered list is data, not control flow: swapping
/// the offline gazetteer (step 5) for a bigger file, or inserting a new source,
/// means changing the array in `ZoneResolverChain.standard` and nothing else.
protocol ZoneResolver: Sendable {
    var matchSource: ZoneMatchSource { get }

    /// `normalizedZoneToken` is already trimmed, whitespace-collapsed and
    /// lowercased by `InputTokenizer`.
    func candidates(for normalizedZoneToken: String) -> [ZoneCandidate]

    /// Everything this resolver could match, for the did-you-mean suggester
    /// (item 9). Additive and optional: the default is an empty vocabulary, so
    /// a resolver that cannot enumerate itself just never contributes a
    /// suggestion and resolution is unaffected either way.
    var vocabulary: [ZoneVocabularyEntry] { get }
}

extension ZoneResolver {
    var vocabulary: [ZoneVocabularyEntry] { [] }
}

/// What the chain concluded about a single token.
enum ZoneResolution: Equatable, Sendable {
    case resolved(ResolvedZone)
    /// More than one meaning. The spec is absolute here: always prompt, never
    /// pick a default.
    case ambiguous([ZoneCandidate])
    case unknown
}

struct ZoneResolverChain: Sendable {
    let resolvers: [any ZoneResolver]

    /// The five resolvers from the spec, in order.
    static let standard = ZoneResolverChain(resolvers: [
        AliasZoneResolver(),
        FoundationAbbreviationZoneResolver(),
        TimeZoneDatabaseCityResolver(),
        CountryZoneResolver(),
        OfflineFallbackZoneResolver(),
    ])

    func resolve(_ normalizedZoneToken: String) -> ZoneResolution {
        for resolver in resolvers {
            let candidates = Self.validUniqueCandidates(
                resolver.candidates(for: normalizedZoneToken)
            )
            guard let onlyCandidate = candidates.first else { continue }

            if candidates.count == 1,
               let timeZone = TimeZone(identifier: onlyCandidate.timeZoneIdentifier) {
                return .resolved(ResolvedZone(
                    timeZone: timeZone,
                    displayName: onlyCandidate.echoDisplayName,
                    representativeCities: onlyCandidate.echoRepresentativeCities,
                    matchSource: onlyCandidate.matchSource,
                    originalToken: normalizedZoneToken
                ))
            }
            return .ambiguous(candidates)
        }
        return .unknown
    }

    /// Drops identifiers this OS cannot build a `TimeZone` from (so a stale
    /// table entry degrades to "not found" rather than crashing) and collapses
    /// repeats while preserving table order — table order is curated, so it is
    /// also the order the picker shows.
    private static func validUniqueCandidates(_ candidates: [ZoneCandidate]) -> [ZoneCandidate] {
        var seenIdentifiers = Set<String>()
        return candidates.filter { candidate in
            guard TimeZone(identifier: candidate.timeZoneIdentifier) != nil else { return false }
            return seenIdentifiers.insert(candidate.timeZoneIdentifier).inserted
        }
    }
}
