package dev.thisolivier.timeconverter.core.parsing

/** One did-you-mean candidate. [token] is what a chip writes; [label] is what it shows. */
data class ZoneSuggestion(
    val token: String,
    val label: String,
    val editDistance: Int,
    val matchSource: ZoneMatchSource,
)

/**
 * Did-you-mean for P5 — port of Swift `ZoneSuggestionEngine`, walking the
 * chain's vocabulary. Policy (decided 2026-10-21):
 *
 * 1. Never auto-accept — this returns candidates, only a chip tap applies one.
 * 2. Distance ≤ 2, and ≤ 1 for tokens of 4 characters or fewer.
 * 3. Zone codes are withheld from code-shaped typos unless exactly one survives
 *    (`cst` must never offer `cet`); place names are always offered.
 * 4. Closer first, then places over codes, then earlier chain levels, then alphabetical.
 * 5. At most 3, deduped by token across chain levels (the best-ranked copy wins).
 */
object ZoneSuggestionEngine {
    const val MAXIMUM_SUGGESTION_COUNT = 3
    const val SHORT_TOKEN_LENGTH_THRESHOLD = 4
    const val ABBREVIATION_SHAPE_LENGTH_THRESHOLD = 5

    private class ScoredEntry(val entry: ZoneVocabularyEntry, val editDistance: Int, val chainRank: Int)

    /** Policy 4's total order. */
    private val ranking: Comparator<ScoredEntry> = compareBy<ScoredEntry> { it.editDistance }
        .thenBy { it.entry.shape != ZoneVocabularyEntry.Shape.PlaceName }
        .thenBy { it.chainRank }
        .thenBy { it.entry.token }

    fun suggestions(
        unknownToken: String,
        resolverChain: ZoneResolverChain = ZoneResolverChain.standard,
        limit: Int = MAXIMUM_SUGGESTION_COUNT,
    ): List<ZoneSuggestion> {
        val token = unknownToken.trim()
        if (token.isEmpty()) return emptyList()
        val allowedDistance = if (token.length <= SHORT_TOKEN_LENGTH_THRESHOLD) 1 else 2
        return applyingAbbreviationPolicy(bestMatchPerToken(token, allowedDistance, resolverChain), token)
            .sortedWith(ranking)
            .take(limit)
            .map { ZoneSuggestion(it.entry.token, it.entry.suggestionLabel, it.editDistance, it.entry.matchSource) }
    }

    private fun bestMatchPerToken(token: String, allowedDistance: Int, resolverChain: ZoneResolverChain): List<ScoredEntry> {
        val bestByToken = HashMap<String, ScoredEntry>()
        resolverChain.resolvers.forEachIndexed { chainRank, resolver ->
            for (entry in resolver.vocabulary) {
                val editDistance = EditDistance.levenshtein(token, entry.token, allowedDistance)
                if (editDistance == null || editDistance == 0) continue
                val scored = ScoredEntry(entry, editDistance, chainRank)
                val incumbent = bestByToken[entry.token]
                if (incumbent == null || ranking.compare(scored, incumbent) < 0) bestByToken[entry.token] = scored
            }
        }
        return bestByToken.values.toList()
    }

    /** Policy 3: two or more surviving codes are mutually one edit apart, so none is defensible. */
    private fun applyingAbbreviationPolicy(matches: List<ScoredEntry>, unknownToken: String): List<ScoredEntry> {
        if (!isAbbreviationShaped(unknownToken)) return matches
        val abbreviationCount = matches.count { it.entry.shape == ZoneVocabularyEntry.Shape.Abbreviation }
        if (abbreviationCount <= 1) return matches
        return matches.filter { it.entry.shape == ZoneVocabularyEntry.Shape.PlaceName }
    }

    fun isAbbreviationShaped(token: String): Boolean =
        token.length <= ABBREVIATION_SHAPE_LENGTH_THRESHOLD && token.all { it.isLetter() }
}
