package dev.thisolivier.timeconverter.core.parsing

/**
 * Splits a freeform string into its grammar parts — port of Swift
 * `InputTokenizer`: normalise, match the time (or a leading `now`) at the
 * start, then cut the rest in two around the **first standalone** `in`/`to`.
 *
 * Either side may be empty (the parser defaults it to the device zone), and so
 * may the time: a bare zone (`ET`, `Tokyo`) or a leading `now` leaves it null.
 * Every zone token carries the [RawTextRange] a chip rewrites.
 */
object InputTokenizer {
    /** One zone token: the normalised text the resolvers see, and where it came from in the raw input. */
    data class ZoneToken(val text: String, val rawRange: RawTextRange)

    /** At least one zone side is always non-null: a time with no zone at all is P2. */
    data class Tokens(
        /** Null for a bare zone or a leading `now`: the parser reads the current clock. */
        val time: ParsedTime?,
        val sourceZone: ZoneToken?,
        val conjunction: Conjunction?,
        val targetZone: ZoneToken?,
    ) {
        val sourceZoneToken: String? get() = sourceZone?.text
        val targetZoneToken: String? get() = targetZone?.text
    }

    sealed interface Result {
        data class Tokenized(val tokens: Tokens) : Result
        data class Prompted(val prompt: Prompt) : Result
    }

    private const val NOW_KEYWORD = "now"

    fun normalize(input: String): String = NormalizedInput.normalizing(input).normalizedText

    fun tokenize(input: String): Result {
        val normalized = NormalizedInput.normalizing(input)
        val normalizedText = normalized.normalizedText

        val leadingTime = leadingTime(normalizedText)
            ?: return bareZoneTokens(normalized)?.let { Result.Tokenized(it) }
                ?: Result.Prompted(Prompt.TimeNotFound(normalizedText))

        val remainingWords = words(leadingTime.remainder, leadingTime.remainderStartOffset)
        // The *first* standalone conjunction: `porto` contains `to` but is not the word `to`.
        val conjunctionIndex = remainingWords.indexOfFirst { Conjunction.fromWord(it.text) != null }

        if (conjunctionIndex < 0) {
            // No conjunction: whatever follows the time is where the time *is* — the source.
            val sourceZone = zoneToken(remainingWords, normalized)
                ?: return Result.Prompted(Prompt.ZoneNotFound(leadingTime.time))
            return Result.Tokenized(Tokens(leadingTime.time, sourceZone, null, null))
        }

        val conjunction = Conjunction.fromWord(remainingWords[conjunctionIndex].text)
        val sourceZone = zoneToken(remainingWords.subList(0, conjunctionIndex), normalized)
        val targetZone = zoneToken(remainingWords.subList(conjunctionIndex + 1, remainingWords.size), normalized)
        // A conjunction with nothing on either side (`7pm in`) still names no zone.
        if (sourceZone == null && targetZone == null) return Result.Prompted(Prompt.ZoneNotFound(leadingTime.time))
        return Result.Tokenized(Tokens(leadingTime.time, sourceZone, conjunction, targetZone))
    }

    // Leading time

    /** `time` is null for the `now` keyword (item 23). */
    private class LeadingTime(val time: ParsedTime?, val remainder: String, val remainderStartOffset: Int)

    private fun leadingTime(normalizedText: String): LeadingTime? {
        TimeTokenParser.matchAtStart(normalizedText)?.let { timeMatch ->
            return LeadingTime(timeMatch.time, timeMatch.remainder, timeMatch.remainderStartOffset)
        }
        if (normalizedText != NOW_KEYWORD && !normalizedText.startsWith("$NOW_KEYWORD ")) return null
        // Single spaces after normalisation, so the remainder starts one past the keyword.
        val remainderStartOffset = minOf(NOW_KEYWORD.length + 1, normalizedText.length)
        return LeadingTime(null, normalizedText.substring(remainderStartOffset), remainderStartOffset)
    }

    // Bare zone (item 22)

    /**
     * The whole input as one target-side zone token, when it structurally could
     * name a place; null means P1. Never "did it resolve" — a bare `Lodnon` must
     * reach P5's chips and a bare `CST` P4's picker. Rejected: input starting
     * with a digit, input with no letter, input containing a standalone `in`/`to`.
     */
    private fun bareZoneTokens(normalized: NormalizedInput): Tokens? {
        val text = normalized.normalizedText
        if (text.isEmpty() || isNumber(text.codePointAt(0))) return null
        if (text.codePoints().noneMatch { Character.isLetter(it) }) return null
        val allWords = words(text, 0)
        if (allWords.any { Conjunction.fromWord(it.text) != null }) return null
        val bareZoneToken = zoneToken(allWords, normalized) ?: return null
        return Tokens(time = null, sourceZone = null, conjunction = null, targetZone = bareZoneToken)
    }

    /** Swift `Character.isNumber`: decimal digits, letter numbers (`Ⅻ`) and other numbers (`½`). */
    private fun isNumber(codePoint: Int): Boolean = when (Character.getType(codePoint)) {
        Character.DECIMAL_DIGIT_NUMBER.toInt(), Character.LETTER_NUMBER.toInt(), Character.OTHER_NUMBER.toInt() -> true
        else -> false
    }

    // Word scanning

    private class Word(val text: String, val normalizedStart: Int, val normalizedEnd: Int)

    /** Words of an already-normalised fragment, with offsets into the whole normalised input. */
    private fun words(normalizedFragment: String, fragmentStartOffset: Int): List<Word> {
        val scannedWords = ArrayList<Word>()
        var offsetWithinFragment = 0
        for (wordText in normalizedFragment.split(' ')) {
            if (wordText.isNotEmpty()) {
                val start = fragmentStartOffset + offsetWithinFragment
                scannedWords.add(Word(wordText, start, start + wordText.length))
            }
            offsetWithinFragment += wordText.length + 1
        }
        return scannedWords
    }

    /** First character of the first word to last of the last, so inner whitespace runs are covered. */
    private fun zoneToken(words: List<Word>, normalized: NormalizedInput): ZoneToken? {
        if (words.isEmpty()) return null
        val rawRange = normalized.rawRange(words.first().normalizedStart, words.last().normalizedEnd) ?: return null
        return ZoneToken(words.joinToString(" ") { it.text }, rawRange)
    }
}
