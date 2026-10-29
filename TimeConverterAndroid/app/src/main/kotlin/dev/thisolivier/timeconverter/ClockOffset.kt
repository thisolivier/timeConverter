package dev.thisolivier.timeconverter

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.sign

/**
 * The Clocks tab's offset: minutes from now, unbounded, moved by an endless
 * dial. Port of the iPhone's `ClockOffset.swift`, kept out of the view so its
 * rules are tested on the JVM.
 *
 * Two parts: minutes **settled** by finished drags, and the minutes of the drag
 * **in progress**. The clock reads their sum snapped to 15 minutes; the dial's
 * tick strip draws the unsnapped sum so it follows the finger.
 */
data class ClockOffset(val settledMinutes: Double = 0.0, val draggedMinutes: Double = 0.0) {
    /** The offset the clock shows: settled plus in-progress, snapped. */
    val minutes: Double get() = snapped(settledMinutes + draggedMinutes)

    /** The unsnapped position, for drawing the dial mid-drag. */
    val continuousMinutes: Double get() = settledMinutes + draggedMinutes

    /** What `WorldClock.readings` takes. */
    val wholeMinutes: Int get() = minutes.toInt()

    /** A drag in progress: rightwards is forwards; a whole track width is twelve hours, however many times over. */
    fun dragged(translationWidth: Double, trackWidth: Double): ClockOffset {
        if (trackWidth <= 0) return this
        return copy(draggedMinutes = translationWidth / trackWidth * MINUTES_PER_TRACK_WIDTH)
    }

    /** The finger lifted: bank the drag, snapped, so the next swipe adds to it. */
    fun settled(): ClockOffset = ClockOffset(settledMinutes = minutes)

    /** Accessibility's increment / decrement: one step. */
    fun stepped(steps: Int): ClockOffset = ClockOffset(settledMinutes = minutes + steps * STEP_MINUTES)

    companion object {
        const val STEP_MINUTES = 15.0
        /** One full-width swipe across the dial is 12 hours. */
        const val MINUTES_PER_TRACK_WIDTH = 720.0

        /** The DEBUG `clockOffsetMinutes` start, snapped. */
        fun launching(minutes: Int): ClockOffset = ClockOffset(settledMinutes = snapped(minutes.toDouble()))

        /** Nearest step, halves away from zero (Swift's `.rounded()`). `+ 0.0` turns `-0.0` into `0.0`. */
        fun snapped(minutes: Double): Double {
            val steps = minutes / STEP_MINUTES
            return sign(steps) * floor(abs(steps) + 0.5) * STEP_MINUTES + 0.0
        }
    }
}
