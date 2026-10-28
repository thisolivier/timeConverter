package dev.thisolivier.timeconverter.core.parsing

/**
 * The normalised working copy of the user's input — trimmed, whitespace
 * collapsed, lowercased — *plus* the map back to the raw string it came from.
 * Port of Swift `NormalizedInput`.
 *
 * Normalisation runs one code point at a time, recording for every normalised
 * `Char` the raw span of the code point that produced it, so:
 * - collapsed whitespace (`New   York`) still maps back to the whole typed run;
 * - length-changing lowercasing (`İ` → `i̇`) keeps both strings aligned;
 * - a token ending on a surrogate pair maps to the whole pair, never half.
 *
 * Offsets are UTF-16 units (Kotlin `String` indices); Swift counts
 * `Character`s. They differ only when an astral character (emoji) or a
 * multi-scalar grapheme sits before the token — see `RawTextRange`.
 */
class NormalizedInput private constructor(
    val rawInput: String,
    /** Trimmed, whitespace-collapsed, lowercased. */
    val normalizedText: String,
    private val rawStartOffsets: IntArray,
    private val rawEndOffsets: IntArray,
) {
    /** Translates a half-open normalised range to raw offsets; null when empty or out of bounds. */
    fun rawRange(normalizedStart: Int, normalizedEnd: Int): RawTextRange? {
        if (normalizedStart >= normalizedEnd || normalizedStart < 0 || normalizedEnd > rawStartOffsets.size) return null
        return RawTextRange(rawStartOffsets[normalizedStart], rawEndOffsets[normalizedEnd - 1])
    }

    companion object {
        fun normalizing(rawInput: String): NormalizedInput {
            val builder = StringBuilder()
            val starts = ArrayList<Int>()
            val ends = ArrayList<Int>()
            var separatorIsPending = false
            var rawIndex = 0
            while (rawIndex < rawInput.length) {
                val codePoint = rawInput.codePointAt(rawIndex)
                val codePointEnd = rawIndex + Character.charCount(codePoint)
                if (isWhitespace(codePoint)) {
                    // Leading whitespace is dropped; interior runs become one space,
                    // emitted lazily so trailing whitespace is dropped too.
                    if (builder.isNotEmpty()) separatorIsPending = true
                } else {
                    if (separatorIsPending) {
                        // Attributed to the character that follows, as in Swift. Tokens
                        // never start or end on a space, so no range is anchored here.
                        builder.append(' ')
                        starts.add(rawIndex)
                        ends.add(codePointEnd)
                        separatorIsPending = false
                    }
                    for (lowercasedChar in String(Character.toChars(codePoint)).lowercase()) {
                        builder.append(lowercasedChar)
                        starts.add(rawIndex)
                        ends.add(codePointEnd)
                    }
                }
                rawIndex = codePointEnd
            }
            return NormalizedInput(rawInput, builder.toString(), starts.toIntArray(), ends.toIntArray())
        }

        /** Kotlin's `Char.isWhitespace` rule, per code point (Unicode white space and space separators). */
        private fun isWhitespace(codePoint: Int): Boolean =
            Character.isWhitespace(codePoint) || Character.isSpaceChar(codePoint)
    }
}
