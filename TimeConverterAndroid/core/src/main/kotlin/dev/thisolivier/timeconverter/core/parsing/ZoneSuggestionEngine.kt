package dev.thisolivier.timeconverter.core.parsing

import kotlin.math.abs

/**
 * Did-you-mean for P5 — port of Swift `ZoneSuggestionEngine`'s policy over the
 * interim vocabulary (the vocabulary is interim; the policy is not):
 *
 * 1. Never auto-accept — this returns candidates, only a chip tap applies one.
 * 2. Distance ≤ 2, and ≤ 1 for tokens of 4 characters or fewer.
 * 3. Zone codes are withheld from code-shaped typos unless exactly one survives
 *    (`cst` must never offer `cet`); place names are always offered.
 * 4. Closer first, then places over codes, then alphabetical.
 * 5. At most 3.
 */
object ZoneSuggestionEngine {
    const val MAXIMUM_SUGGESTION_COUNT = 3
    private const val SHORT_TOKEN_LENGTH_THRESHOLD = 4
    private const val ABBREVIATION_SHAPE_LENGTH_THRESHOLD = 5

    data class Suggestion(val token: String, val label: String, val editDistance: Int)

    fun suggestions(
        unknownToken: String,
        vocabulary: List<InterimZoneTable.VocabularyEntry> = InterimZoneTable.vocabulary,
        limit: Int = MAXIMUM_SUGGESTION_COUNT,
    ): List<Suggestion> {
        val token = unknownToken.trim()
        if (token.isEmpty()) return emptyList()
        val allowedDistance = if (token.length <= SHORT_TOKEN_LENGTH_THRESHOLD) 1 else 2

        val scoredEntries = vocabulary.distinctBy { it.token }.mapNotNull { entry ->
            val distance = EditDistance.levenshtein(token, entry.token, allowedDistance)
            if (distance == null || distance == 0) null else entry to distance
        }
        return applyingAbbreviationPolicy(scoredEntries, token)
            .sortedWith(
                compareBy<Pair<InterimZoneTable.VocabularyEntry, Int>> { it.second }
                    .thenBy { it.first.isAbbreviation }
                    .thenBy { it.first.token }
            )
            .take(limit)
            .map { (entry, distance) -> Suggestion(entry.token, entry.suggestionLabel, distance) }
    }

    private fun applyingAbbreviationPolicy(
        scoredEntries: List<Pair<InterimZoneTable.VocabularyEntry, Int>>,
        unknownToken: String,
    ): List<Pair<InterimZoneTable.VocabularyEntry, Int>> {
        if (!isAbbreviationShaped(unknownToken)) return scoredEntries
        val abbreviationMatchCount = scoredEntries.count { it.first.isAbbreviation }
        if (abbreviationMatchCount <= 1) return scoredEntries
        return scoredEntries.filter { !it.first.isAbbreviation }
    }

    fun isAbbreviationShaped(token: String): Boolean =
        token.length <= ABBREVIATION_SHAPE_LENGTH_THRESHOLD && token.all { it.isLetter() }
}

/** Bounded Levenshtein — port of Swift `EditDistance`. Null when the distance exceeds `limit`. */
object EditDistance {
    fun levenshtein(first: String, second: String, limit: Int): Int? {
        if (abs(first.length - second.length) > limit) return null
        if (first.isEmpty()) return second.length.takeIf { it <= limit }
        if (second.isEmpty()) return first.length.takeIf { it <= limit }

        var previousRow = IntArray(second.length + 1) { it }
        for (firstIndex in first.indices) {
            val currentRow = IntArray(second.length + 1)
            currentRow[0] = firstIndex + 1
            for (secondIndex in second.indices) {
                val substitutionCost = previousRow[secondIndex] + if (first[firstIndex] == second[secondIndex]) 0 else 1
                val insertionCost = currentRow[secondIndex] + 1
                val deletionCost = previousRow[secondIndex + 1] + 1
                currentRow[secondIndex + 1] = minOf(substitutionCost, insertionCost, deletionCost)
            }
            // Costs never decrease down the matrix, so a row already over the limit cannot recover.
            if (currentRow.min() > limit) return null
            previousRow = currentRow
        }
        return previousRow[second.length].takeIf { it <= limit }
    }
}
