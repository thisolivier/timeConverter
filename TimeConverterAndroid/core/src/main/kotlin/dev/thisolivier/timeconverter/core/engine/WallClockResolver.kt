package dev.thisolivier.timeconverter.core.engine

import dev.thisolivier.timeconverter.core.parsing.ParsedTime
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * "This wall-clock time, today, in this zone" → one instant, with the spec's
 * DST policy made explicit. Port of Swift `WallClockResolver`.
 *
 * - exists once → that instant
 * - exists twice (clocks went back) → the **earlier** instant
 * - never happens (clocks went forward) → the **next valid instant**, i.e. the transition
 */
object WallClockResolver {
    enum class Disposition { Unambiguous, RepeatedTimeTookEarlier, NonexistentTimeShiftedForward }

    data class Outcome(val instant: Instant, val disposition: Disposition)

    /** `referenceInstant` supplies "today", read in the source zone. */
    fun resolve(wallClock: ParsedTime, referenceInstant: Instant, zone: ZoneId): Outcome {
        val today: LocalDate = referenceInstant.atZone(zone).toLocalDate()
        val requestedLocal = LocalDateTime.of(today, java.time.LocalTime.of(wallClock.hour, wallClock.minute))
        val rules = zone.rules
        val validOffsets = rules.getValidOffsets(requestedLocal)
        return when (validOffsets.size) {
            1 -> Outcome(requestedLocal.toInstant(validOffsets.single()), Disposition.Unambiguous)
            0 -> Outcome(rules.getTransition(requestedLocal).instant, Disposition.NonexistentTimeShiftedForward)
            else -> Outcome(
                validOffsets.minOf { requestedLocal.toInstant(it) },
                Disposition.RepeatedTimeTookEarlier,
            )
        }
    }
}
