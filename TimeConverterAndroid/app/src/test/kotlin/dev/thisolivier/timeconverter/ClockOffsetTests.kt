package dev.thisolivier.timeconverter

import org.junit.Assert.assertEquals
import org.junit.Test

/** The endless dial, as rules — the twin of the iPhone's `ClockOffsetTests.swift`. */
class ClockOffsetTests {
    @Test
    fun aFullWidthSwipeIsTwelveHoursAndTheNextSwipeAddsToIt() {
        var offset = ClockOffset().dragged(translationWidth = 390.0, trackWidth = 390.0)
        assertEquals(720.0, offset.minutes, 0.0)
        offset = offset.settled()
        assertEquals(ClockOffset(settledMinutes = 720.0, draggedMinutes = 0.0), offset)

        offset = offset.dragged(390.0, 390.0).settled()
        assertEquals(1440.0, offset.minutes, 0.0)
        assertEquals(1440, offset.wholeMinutes)

        // Leftwards is backwards; nothing stops it going past zero.
        offset = offset.dragged(-3 * 390.0, 390.0).settled()
        assertEquals(-720.0, offset.minutes, 0.0)
    }

    @Test
    fun theValueSnapsToFifteenMinutesButTheStripDoesNot() {
        var offset = ClockOffset().dragged(10.0, 720.0)
        assertEquals(15.0, offset.minutes, 0.0)
        assertEquals(10.0, offset.continuousMinutes, 0.0)
        offset = offset.dragged(7.0, 720.0)
        assertEquals(0.0, offset.minutes, 0.0)
        assertEquals(0.0, offset.settled().settledMinutes, 0.0)
        // Halves round away from zero, both ways, as Swift's `.rounded()` does.
        assertEquals(15.0, ClockOffset.snapped(7.5), 0.0)
        assertEquals(-15.0, ClockOffset.snapped(-7.5), 0.0)
    }

    @Test
    fun aZeroWidthTrackIsIgnored() {
        assertEquals(0.0, ClockOffset().dragged(100.0, 0.0).minutes, 0.0)
    }

    @Test
    fun aDragFromALaunchOffsetStartsThereAndResetIsAFreshOffset() {
        val moved = ClockOffset.launching(1140).dragged(50.0, 390.0)
        assertEquals(1140.0 + 50.0 / 390.0 * 720.0, moved.continuousMinutes, 1e-9)
        assertEquals(0, ClockOffset().wholeMinutes)
        assertEquals(null, ClockOffset().minutes.takeIf { it != 0.0 })
    }

    @Test
    fun launchMinutesAreSnapped() {
        assertEquals(1140, ClockOffset.launching(1140).wholeMinutes)
        assertEquals(15, ClockOffset.launching(22).wholeMinutes)
        assertEquals(-960, ClockOffset.launching(-960).wholeMinutes)
    }

    @Test
    fun accessibilityStepsByOneTick() {
        val offset = ClockOffset().stepped(1).stepped(1)
        assertEquals(30, offset.wholeMinutes)
        assertEquals(-15, offset.stepped(-3).wholeMinutes)
    }
}
