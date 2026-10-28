package dev.thisolivier.timeconverter.core.parsing

import kotlin.math.abs

/**
 * Bounded Levenshtein — port of Swift `EditDistance`. Null when the distance
 * exceeds [limit]; the length pre-check rejects most of the vocabulary before
 * any matrix work, which keeps the ~1,100-entry scan cheap.
 */
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
