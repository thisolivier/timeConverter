package dev.thisolivier.timeconverter.core.parsing

/**
 * The parser's working copy of the input — trimmed, lowercased, whitespace
 * collapsed — plus the map back to raw offsets that chips need. Port of the
 * idea behind Swift `NormalizedInput`.
 *
 * Lowercasing is per character (`lowercaseChar`) so the copy stays one char
 * per kept raw char and the offset map stays a plain array.
 */
class NormalizedInput(val rawInput: String) {
    val text: String
    /** `rawOffsets[normalizedIndex]` is where that character sits in [rawInput]. */
    private val rawOffsets: IntArray

    init {
        val builder = StringBuilder()
        val offsets = ArrayList<Int>()
        var pendingSpaceOffset: Int? = null
        rawInput.forEachIndexed { rawIndex, character ->
            if (character.isWhitespace()) {
                if (builder.isNotEmpty() && pendingSpaceOffset == null) pendingSpaceOffset = rawIndex
            } else {
                pendingSpaceOffset?.let { spaceOffset ->
                    builder.append(' ')
                    offsets.add(spaceOffset)
                }
                pendingSpaceOffset = null
                builder.append(character.lowercaseChar())
                offsets.add(rawIndex)
            }
        }
        text = builder.toString()
        rawOffsets = offsets.toIntArray()
    }

    /** Translates a non-empty half-open normalised range to raw offsets. */
    fun rawRange(normalizedStart: Int, normalizedEnd: Int): RawTextRange =
        RawTextRange(rawOffsets[normalizedStart], rawOffsets[normalizedEnd - 1] + 1)
}
