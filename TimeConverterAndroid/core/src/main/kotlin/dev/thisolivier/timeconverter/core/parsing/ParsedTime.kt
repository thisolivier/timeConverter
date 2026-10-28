package dev.thisolivier.timeconverter.core.parsing

/**
 * A wall-clock time as typed, 24-hour internally. Port of Swift `ParsedTime`.
 */
data class ParsedTime(val hour: Int, val minute: Int) {
    /** `12:00` — zero-padded 24-hour form, the shape the shared fixtures use. */
    val canonicalDescription: String
        get() = "%02d:%02d".format(hour, minute)

    companion object {
        /** Parses the fixture form `HH:mm`; null for anything else. */
        fun fromCanonical(text: String): ParsedTime? {
            val match = Regex("""^(\d{2}):(\d{2})$""").matchEntire(text) ?: return null
            return ParsedTime(match.groupValues[1].toInt(), match.groupValues[2].toInt())
        }
    }
}
