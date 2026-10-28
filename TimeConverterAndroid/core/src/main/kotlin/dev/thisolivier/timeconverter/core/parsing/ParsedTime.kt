package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.TimeFormatting
import java.time.Instant
import java.time.ZoneId

/**
 * A wall-clock time as typed, 24-hour internally. Port of Swift `ParsedTime`.
 */
data class ParsedTime(val hour: Int, val minute: Int) {
    /** `12:00` — zero-padded 24-hour form, the shape the shared fixtures use. */
    val canonicalDescription: String
        get() = "%02d:%02d".format(hour, minute)

    /** `7:00 pm` — the prose form Swift calls `canonicalDescription`; used in prompt copy and the DST note. */
    val twelveHourDescription: String
        get() = TimeFormatting.twelveHourDescription(hour, minute)

    companion object {
        /**
         * The wall clock [instant] shows in [zone] — what a bare zone or `now`
         * means by "now". Minutes are kept, never rounded.
         */
        fun wallClock(instant: Instant, zone: ZoneId): ParsedTime {
            val local = instant.atZone(zone)
            return ParsedTime(local.hour, local.minute)
        }

        /** Parses the fixture form `HH:mm`; null for anything else. */
        fun fromCanonical(text: String): ParsedTime? {
            val match = Regex("""^(\d{2}):(\d{2})$""").matchEntire(text) ?: return null
            return ParsedTime(match.groupValues[1].toInt(), match.groupValues[2].toInt())
        }
    }
}
