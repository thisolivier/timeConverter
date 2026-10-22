import Foundation

/// One did-you-mean candidate for an unrecognised zone token.
struct ZoneSuggestion: Equatable, Sendable {
    /// The normalised vocabulary token — this is the text that replaces the
    /// typo in the input when the chip is tapped.
    let token: String
    /// Chip-facing form: `London`, `New York`, `PST`.
    let label: String
    let editDistance: Int
    let matchSource: ZoneMatchSource
}

/// Backlog item 9 — "did you mean…" for `Prompt.unknownZone` (P5).
///
/// Walks the resolver chain's **vocabulary** (the additive capability on
/// `ZoneResolver`), scores every entry by bounded edit distance against the
/// token the user typed, and returns the best few as replacement candidates.
/// Resolution itself is untouched; this is a second, separate read of the same
/// tables.
///
/// ## Policy (decided 2026-10-21, see `docs/ux-v1-proposal.md` Decisions)
///
/// 1. **Never auto-accept.** Not even a unique distance-1 match. A silently
///    corrected wrong city produces a conversion that *looks* right, which is
///    worse than a prompt. The engine returns candidates; only a tap applies
///    one.
/// 2. **Distance ≤ 2, and ≤ 1 for tokens of 4 characters or fewer.** On a
///    4-character token, two edits is most of the word.
/// 3. **Abbreviation vocabulary is withheld from abbreviation-shaped typos
///    unless exactly one candidate survives.** Zone codes are mutually one edit
///    apart — `cst`, `cet`, `ct`, `est`, `mst` all sit in each other's
///    neighbourhood — so offering them for a mistyped code is a coin flip
///    dressed as help. `cst` must never offer `cet`. Place names are always
///    offered; they are long enough for distance to mean something.
/// 4. **Place names outrank abbreviations** at equal distance, then earlier
///    chain levels, then alphabetical order, so the list is stable.
/// 5. **Capped at 3**, deduped by token across chain levels (`cst` is in both
///    abbreviation tables; it appears once, attributed to the earlier level).
enum ZoneSuggestionEngine {
    static let maximumSuggestionCount = 3
    /// At or below this length, only a single edit is allowed.
    static let shortTokenLengthThreshold = 4
    /// At or below this length, an all-letters token is treated as a zone code
    /// for the purposes of policy 3. Over-classifying is the safe direction:
    /// the rule only ever *withholds* abbreviation suggestions.
    static let abbreviationShapeLengthThreshold = 5

    /// Ranked replacements for `unknownToken`, best first. Empty when nothing
    /// is close enough or when policy 3 withholds everything.
    ///
    /// Vocabulary is read fresh on each call. That is roughly 1,100 short
    /// strings through a length-prefiltered bounded Levenshtein, which is
    /// comfortably sub-millisecond — and item 8's debounce means it runs at most
    /// once per 600 ms of typing, not once per keystroke.
    static func suggestions(
        for unknownToken: String,
        in resolverChain: ZoneResolverChain,
        limit: Int = maximumSuggestionCount
    ) -> [ZoneSuggestion] {
        let token = unknownToken.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return [] }

        let allowedDistance = token.count <= shortTokenLengthThreshold ? 1 : 2
        let matches = applyingAbbreviationPolicy(
            to: bestMatchPerToken(for: token, allowedDistance: allowedDistance, in: resolverChain),
            unknownToken: token
        )

        return matches
            .sorted(by: isRankedBefore)
            .prefix(limit)
            .map {
                ZoneSuggestion(
                    token: $0.entry.token,
                    label: $0.entry.suggestionLabel,
                    editDistance: $0.editDistance,
                    matchSource: $0.entry.matchSource
                )
            }
    }

    // MARK: - Scoring

    private struct ScoredEntry {
        let entry: ZoneVocabularyEntry
        let editDistance: Int
        /// Position of the owning resolver in the chain, so an earlier level
        /// wins a tie without the engine hard-coding the order.
        let chainRank: Int
    }

    private static func bestMatchPerToken(
        for token: String,
        allowedDistance: Int,
        in resolverChain: ZoneResolverChain
    ) -> [ScoredEntry] {
        var bestByToken: [String: ScoredEntry] = [:]
        for (chainRank, resolver) in resolverChain.resolvers.enumerated() {
            for entry in resolver.vocabulary {
                guard let editDistance = EditDistance.levenshtein(
                    token, entry.token, limitedTo: allowedDistance
                ), editDistance > 0 else { continue }

                let scored = ScoredEntry(
                    entry: entry, editDistance: editDistance, chainRank: chainRank
                )
                guard let incumbent = bestByToken[entry.token] else {
                    bestByToken[entry.token] = scored
                    continue
                }
                if isRankedBefore(scored, incumbent) {
                    bestByToken[entry.token] = scored
                }
            }
        }
        return Array(bestByToken.values)
    }

    /// Policy 3. Two or more surviving zone codes means they are mutually one
    /// edit apart, so none of them is a defensible suggestion; place names
    /// carry on regardless.
    private static func applyingAbbreviationPolicy(
        to matches: [ScoredEntry],
        unknownToken: String
    ) -> [ScoredEntry] {
        guard isAbbreviationShaped(unknownToken) else { return matches }
        let abbreviationMatches = matches.filter { $0.entry.shape == .abbreviation }
        guard abbreviationMatches.count > 1 else { return matches }
        return matches.filter { $0.entry.shape == .placeName }
    }

    static func isAbbreviationShaped(_ token: String) -> Bool {
        token.count <= abbreviationShapeLengthThreshold && token.allSatisfy(\.isLetter)
    }

    /// Policy 4's total order: closer first, then places over codes, then
    /// earlier chain levels, then alphabetically so the output never wobbles.
    private static func isRankedBefore(_ left: ScoredEntry, _ right: ScoredEntry) -> Bool {
        if left.editDistance != right.editDistance {
            return left.editDistance < right.editDistance
        }
        if left.entry.shape != right.entry.shape {
            return left.entry.shape == .placeName
        }
        if left.chainRank != right.chainRank {
            return left.chainRank < right.chainRank
        }
        return left.entry.token < right.entry.token
    }
}
