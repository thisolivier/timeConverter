package dev.thisolivier.timeconverter.core.parsing

/**
 * The time half of the grammar — port of Swift `TimeTokenParser`:
 *
 * ```
 * <time> := H[H]:mm                  (24-hour)
 *         | H[H]mm                   (compact 24-hour, item 27)
 *         | H[H][[:]mm] [space] am|pm  (space optional)
 * ```
 *
 * Matches only at the start of the already-normalised input and hands back
 * what follows. A meridiem on an hour above 12 is accepted when it agrees
 * (`18pm` = 18:00) and rejected when it contradicts (`13:00 am`).
 */
object TimeTokenParser {
    data class Match(
        val time: ParsedTime,
        /** Everything after the matched time, leading whitespace removed. */
        val remainder: String,
        /** Offset within the normalised input at which `remainder` begins. */
        val remainderStartOffset: Int,
    )

    // The colon is optional in both forms since item 27 (2026-10-28): `1500`,
    // `930`, `600pm`. The last two digits are always the minutes, and the
    // lookahead still rejects `15000`, `1500m`, `1500et`.
    private val twelveHourPattern = Regex("""^(\d{1,2})(?::?(\d{2}))?[ ]?([ap]m)(?=[ ]|$)""")
    private val twentyFourHourPattern = Regex("""^(\d{1,2}):?(\d{2})(?=[ ]|$)""")

    /** Tries the 12-hour form first so `9:30 am …` is never read as `9:30` + zone `am…`. */
    fun matchAtStart(normalizedInput: String): Match? {
        twelveHourPattern.find(normalizedInput)?.let { twelveHourMatch ->
            val (hourText, minuteText, meridiemText) = twelveHourMatch.destructured
            // A contradicting meridiem is a failed time, not a retry as 24-hour.
            val time = meridiemTime(hourText, minuteText.ifEmpty { null }, meridiemText) ?: return null
            return match(time, normalizedInput, twelveHourMatch.range.last + 1)
        }
        twentyFourHourPattern.find(normalizedInput)?.let { twentyFourHourMatch ->
            val (hourText, minuteText) = twentyFourHourMatch.destructured
            val hour = hourText.toInt()
            val minute = minuteText.toInt()
            if (hour !in 0..23 || minute !in 0..59) return null
            return match(ParsedTime(hour, minute), normalizedInput, twentyFourHourMatch.range.last + 1)
        }
        return null
    }

    private fun meridiemTime(hourText: String, minuteText: String?, meridiemText: String): ParsedTime? {
        val statedHour = hourText.toInt()
        if (statedHour !in 0..23) return null
        val minute = minuteText?.toInt() ?: 0
        if (minute !in 0..59) return null
        val isAfternoon = meridiemText == "pm"
        val hour = when (statedHour) {
            0 -> if (isAfternoon) return null else 0
            in 1..11 -> if (isAfternoon) statedHour + 12 else statedHour
            12 -> if (isAfternoon) 12 else 0
            else -> if (isAfternoon) statedHour else return null
        }
        return ParsedTime(hour, minute)
    }

    private fun match(time: ParsedTime, normalizedInput: String, matchEnd: Int): Match {
        val tail = normalizedInput.substring(matchEnd)
        val leadingWhitespaceCount = tail.takeWhile { it.isWhitespace() }.length
        return Match(
            time = time,
            remainder = tail.trim(),
            remainderStartOffset = matchEnd + leadingWhitespaceCount,
        )
    }
}
