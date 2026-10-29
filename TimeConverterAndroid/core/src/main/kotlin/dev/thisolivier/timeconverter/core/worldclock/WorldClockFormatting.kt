package dev.thisolivier.timeconverter.core.worldclock

import java.time.Instant
import java.time.ZoneId
import kotlin.math.abs

/**
 * The readout's two strings, hand-rolled and locale-independent like
 * `Formatting.kt`. Port of Swift `WorldClockFormatting`.
 */
object WorldClockFormatting {
    private val weekdayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
    private val monthNames = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

    /** A true minus, as the spec writes `−45 min`. */
    const val MINUS_SIGN = "−"

    /** `Today 2:30 PM`, `Tomorrow 9:15 AM`, `Yesterday 11:00 PM`, or `Fri 31 Oct, 9:15 AM` beyond one day. */
    fun readout(dayDifference: Int, shiftedInstant: Instant, localZone: ZoneId, uppercasedTime: String): String =
        when (dayDifference) {
            0 -> "Today $uppercasedTime"
            1 -> "Tomorrow $uppercasedTime"
            -1 -> "Yesterday $uppercasedTime"
            else -> {
                val localDate = shiftedInstant.atZone(localZone).toLocalDate()
                // java.time counts Monday = 1 … Sunday = 7; the table starts on Sunday.
                val weekday = weekdayNames[localDate.dayOfWeek.value % 7]
                val month = monthNames[localDate.monthValue - 1]
                "$weekday ${localDate.dayOfMonth} $month, $uppercasedTime"
            }
        }

    /** `+5 h`, `−45 min`, `+3 d 2 h`, `+1 d 15 min`; null at zero. Zero parts are dropped. */
    fun offsetDescription(minutes: Int): String? {
        if (minutes == 0) return null
        val magnitude = abs(minutes)
        val days = magnitude / 1440
        val hours = (magnitude % 1440) / 60
        val remainingMinutes = magnitude % 60
        val parts = buildList {
            if (days > 0) add("$days d")
            if (hours > 0) add("$hours h")
            if (remainingMinutes > 0) add("$remainingMinutes min")
        }
        return (if (minutes > 0) "+" else MINUS_SIGN) + parts.joinToString(" ")
    }
}
