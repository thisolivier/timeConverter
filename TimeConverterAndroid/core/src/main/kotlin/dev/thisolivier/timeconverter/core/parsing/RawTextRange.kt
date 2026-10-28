package dev.thisolivier.timeconverter.core.parsing

/**
 * A half-open range of offsets into the **raw** string the user typed — not
 * the normalised copy the parser works on. Port of Swift `RawTextRange`.
 *
 * Chip taps rewrite the typed sentence, so every range that leaves the parser
 * is already translated back to raw offsets and nothing downstream has to think
 * about normalisation again.
 *
 * Units are UTF-16 code units (Kotlin `String` indices) where Swift counts
 * `Character`s. The two agree for everything the fixtures contain; they would
 * part only on input carrying emoji or combining marks before the token.
 */
data class RawTextRange(
    /** Inclusive start. */
    val startOffset: Int,
    /** Exclusive end. */
    val endOffset: Int,
) {
    val isEmpty: Boolean get() = endOffset <= startOffset
}

/** Applies a [RawTextRange] to a raw string. Port of Swift `RawTextEditing`. */
object RawTextEditing {
    /**
     * Replaces [range] with [replacement], or returns the input unchanged if
     * the range no longer fits (the field can have been edited since the
     * prompt was produced; doing nothing is the safe answer).
     */
    fun replacing(range: RawTextRange, replacement: String, rawInput: String): String {
        if (!fits(range, rawInput)) return rawInput
        return rawInput.replaceRange(range.startOffset, range.endOffset, replacement)
    }

    /** The substring a range addresses, or null when the range does not fit. */
    fun substring(range: RawTextRange, rawInput: String): String? =
        if (fits(range, rawInput)) rawInput.substring(range.startOffset, range.endOffset) else null

    private fun fits(range: RawTextRange, rawInput: String): Boolean =
        range.startOffset >= 0 && range.endOffset <= rawInput.length && range.startOffset <= range.endOffset
}
