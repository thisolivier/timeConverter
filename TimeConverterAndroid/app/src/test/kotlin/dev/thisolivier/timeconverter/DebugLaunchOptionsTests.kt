package dev.thisolivier.timeconverter

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The DEBUG QA extras — the twin of the iOS `LaunchArgumentsClocksTests`. */
class DebugLaunchOptionsTests {
    @Test
    fun favouritesSeedResolvesEachZoneAndSkipsTheUnconvertible() {
        assertNull(DebugLaunchOptions.parse(null, null, null).seededFavourites)
        val seeded = DebugLaunchOptions.parse("London, ET,CST, Kolkata", null, null).seededFavourites
        assertEquals(listOf("Europe/London", "America/New_York", "Asia/Kolkata"), seeded?.map { it.timeZoneIdentifier })
        assertEquals(ZoneLabel.Abbreviation("ET", "Eastern Time"), seeded?.get(1)?.label)
    }

    @Test
    fun selectedTabAndSignedOffsets() {
        assertFalse(DebugLaunchOptions.parse(null, null, null).opensOnClocksTab)
        assertTrue(DebugLaunchOptions.parse(null, "Clocks", null).opensOnClocksTab)
        for ((text, value) in listOf("3" to 3, "m3" to -3, " -3" to -3, "1140" to 1140, "junk" to 0, null to 0)) {
            assertEquals("$text", value, DebugLaunchOptions.signedInteger(text))
        }
    }

    @Test
    fun anyExtraMakesTheLaunchScripted() {
        assertFalse(DebugLaunchOptions().isScripted)
        assertTrue(DebugLaunchOptions.parse(null, null, "-960").isScripted)
        assertTrue(DebugLaunchOptions.parse("", null, null).isScripted)
    }
}
