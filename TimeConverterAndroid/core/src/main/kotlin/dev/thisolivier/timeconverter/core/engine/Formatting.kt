package dev.thisolivier.timeconverter.core.engine

import java.time.Instant
import java.time.ZoneId
import kotlin.math.abs

/**
 * Deterministic, locale-independent formatting — port of Swift `Formatting.swift`.
 * Hand-rolled on purpose: the spec pins exact shapes (`12:00 pm`, `UTC+5:30`)
 * and a locale-driven formatter would break them on a `de_DE` device.
 */
object TimeFormatting {
    /** `5:00 pm`: no leading zero on the hour, padded minutes, lowercase meridiem. */
    fun twelveHourDescription(hour: Int, minute: Int): String {
        val hourWithinCycle = hour % 12
        val displayHour = if (hourWithinCycle == 0) 12 else hourWithinCycle
        val meridiem = if (hour < 12) "am" else "pm"
        val paddedMinute = if (minute < 10) "0$minute" else "$minute"
        return "$displayHour:$paddedMinute $meridiem"
    }
}

object ZoneDisplayName {
    /** `America/New_York` → `New York`; `UTC` passes through. */
    fun forIdentifier(timeZoneIdentifier: String): String =
        timeZoneIdentifier.substringAfterLast('/').replace('_', ' ')
}

object UtcOffsetFormatting {
    /** `UTC+0`, `UTC-5`, and `UTC+5:30` only when the offset has minutes. */
    fun description(zone: ZoneId, instant: Instant): String =
        description(zone.rules.getOffset(instant).totalSeconds)

    fun description(totalSeconds: Int): String {
        val sign = if (totalSeconds < 0) "-" else "+"
        val absoluteSeconds = abs(totalSeconds)
        val hours = absoluteSeconds / 3600
        val minutes = (absoluteSeconds % 3600) / 60
        if (minutes == 0) return "UTC$sign$hours"
        val paddedMinutes = if (minutes < 10) "0$minutes" else "$minutes"
        return "UTC$sign$hours:$paddedMinutes"
    }
}

/** The footer sentence and its name-free phrase: `São Paulo is 4 hours behind Lisbon.` / `4 hours behind`. */
object RelativeOffsetFormatting {
    /** `differenceInSeconds` is target minus source; positive means the target is ahead. */
    fun sentence(differenceInSeconds: Int, targetPlaceName: String, sourcePlaceName: String): String {
        if (differenceInSeconds == 0) {
            if (targetPlaceName == sourcePlaceName) return "Same time as $sourcePlaceName."
            return "$targetPlaceName is the same time as $sourcePlaceName."
        }
        val direction = if (differenceInSeconds > 0) "ahead of" else "behind"
        val magnitude = hourCountDescription(abs(differenceInSeconds))
        return "$targetPlaceName is $magnitude $direction $sourcePlaceName."
    }

    fun phrase(differenceInSeconds: Int): String {
        if (differenceInSeconds == 0) return "Same time"
        val direction = if (differenceInSeconds > 0) "ahead" else "behind"
        return "${hourCountDescription(abs(differenceInSeconds))} $direction"
    }

    /** `1 hour`, `4 hours`, `4.5 hours`, `5.75 hours` — exact, since offsets are quarter-hours. */
    fun hourCountDescription(seconds: Int): String {
        val wholeHours = seconds / 3600
        val remainderSeconds = seconds % 3600
        if (remainderSeconds == 0) return if (wholeHours == 1) "1 hour" else "$wholeHours hours"
        val hundredthsOfAnHour = (remainderSeconds * 100) / 3600
        var fraction = if (hundredthsOfAnHour < 10) "0$hundredthsOfAnHour" else "$hundredthsOfAnHour"
        if (fraction.endsWith("0")) fraction = fraction.dropLast(1)
        return "$wholeHours.$fraction hours"
    }
}
