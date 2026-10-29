package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import dev.thisolivier.timeconverter.core.presentation.ConverterPresenter
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The world clock, edge by edge — the Kotlin twin of Swift `WorldClockTests`.
 * The shared fixtures pin whole displays; these name the individual rules.
 */
class WorldClockTests {
    private val london = place("Europe/London", "London")
    private val tokyo = place("Asia/Tokyo", "Tokyo")
    private val kolkata = place("Asia/Kolkata", "Kolkata")
    private val easternTime = FavouriteDestination("America/New_York", ZoneLabel.Abbreviation("ET", "Eastern Time"))
    private val losAngeles = ZoneId.of("America/Los_Angeles")
    private val newYork = ZoneId.of("America/New_York")

    /** 3:42 PM on Thu 15 Jan in Los Angeles. */
    private val winterAfternoon = Instant.parse("2026-01-15T23:42:00Z")

    private fun place(identifier: String, name: String) =
        FavouriteDestination(identifier, ZoneLabel.Place(name, isDeviceLocal = false))

    private fun readings(
        favourites: List<FavouriteDestination>,
        minutes: Int = 0,
        now: Instant = winterAfternoon,
        localZone: ZoneId = losAngeles,
    ) = WorldClock.readings(favourites, minutes, now, localZone)

    @Test
    fun `local row comes first and is labelled local`() {
        val display = readings(listOf(london))
        assertEquals(listOf("Los Angeles (local)", "London"), display.rows.map { it.placeName })
        assertTrue(display.rows[0].isLocal)
        assertEquals("", display.rows[0].offsetPhrase)
        assertEquals(london, display.rows[1].favourite)
        assertEquals("Today 3:42 PM", display.readout)
        assertNull(display.offsetDescription)
    }

    @Test
    fun `day markers are relative to the real local today`() {
        val live = readings(listOf(london, tokyo))
        assertEquals("Pacific Time (Los Angeles, Vancouver)", live.rows[0].zoneLine)
        assertEquals("United Kingdom Time (London)", live.rows[1].zoneLine)
        assertEquals("Japan Standard Time (Tokyo) · next day", live.rows[2].zoneLine)

        val shifted = readings(listOf(london, tokyo), minutes = 9 * 60)
        assertEquals("Tomorrow 12:42 AM", shifted.readout)
        assertEquals("Pacific Time (Los Angeles, Vancouver) · next day", shifted.rows[0].zoneLine)
        assertEquals("United Kingdom Time (London) · next day", shifted.rows[1].zoneLine)
        assertEquals("Japan Standard Time (Tokyo) · next day", shifted.rows[2].zoneLine)

        val back = readings(listOf(london), minutes = -16 * 60)
        assertEquals("Yesterday 11:42 PM", back.readout)
        assertEquals("Pacific Time (Los Angeles, Vancouver) · previous day", back.rows[0].zoneLine)
        assertEquals("United Kingdom Time (London)", back.rows[1].zoneLine)
    }

    /** Olivier's build-20 report: sweeping forward never passes through "previous day". */
    @Test
    fun `sweeping forward never shows previous day`() {
        val losAngelesFavourite = place("America/Los_Angeles", "PST")
        val londonEvening = Instant.parse("2026-10-29T21:00:00Z")
        val markers = mutableListOf<String>()
        for (quarterHours in 0..(48 * 4)) {
            val display = readings(listOf(losAngelesFavourite), quarterHours * 15, londonEvening, ZoneId.of("Europe/London"))
            val marker = display.rows[1].zoneLine.split(" · ").drop(1).firstOrNull().orEmpty()
            if (markers.lastOrNull() != marker) markers.add(marker)
        }
        assertEquals(listOf("", "next day", "+2 days"), markers)
    }

    @Test
    fun `a westward favourite can be on the previous day`() {
        val honolulu = place("Pacific/Honolulu", "Honolulu")
        val display = readings(listOf(honolulu), minutes = -(15 * 60 + 12))
        assertEquals("Today 12:30 AM", display.readout)
        assertEquals("10:30", display.rows[1].clockDigits)
        assertTrue(display.rows[1].zoneLine.endsWith(" · previous day"))
        assertEquals("2 hours behind", display.rows[1].offsetPhrase)
    }

    @Test
    fun `minus forty-five minutes`() {
        val display = readings(listOf(london), minutes = -45)
        assertEquals("−45 min", display.offsetDescription)
        assertEquals("Today 2:57 PM", display.readout)
        assertEquals("10:57", display.rows[1].clockDigits)
        assertEquals("PM", display.rows[1].meridiem)
    }

    @Test
    fun `plus three days reads as a weekday and date`() {
        val display = readings(listOf(london), minutes = 3 * 1440)
        assertEquals("Sun 18 Jan, 3:42 PM", display.readout)
        assertEquals("+3 d", display.offsetDescription)
        assertEquals("+3 d 2 h 15 min", readings(emptyList(), minutes = 3 * 1440 + 135).offsetDescription)
        assertEquals("Mon 12 Jan, 3:42 PM", readings(emptyList(), minutes = -3 * 1440).readout)
    }

    @Test
    fun `the offset is unbounded`() {
        val display = readings(listOf(london), minutes = 365 * 1440)
        assertEquals("Fri 15 Jan, 3:42 PM", display.readout)
        assertEquals("+365 d", display.offsetDescription)
    }

    @Test
    fun `a shift into the spring-forward gap moves to the next valid instant`() {
        val display = readings(listOf(london), minutes = 60, now = Instant.parse("2026-03-08T06:30:00Z"), localZone = newYork)
        assertEquals("Today 3:00 AM", display.readout)
        assertEquals("7:00", display.rows[1].clockDigits)
        assertEquals("4 hours ahead", display.rows[1].offsetPhrase)
    }

    @Test
    fun `a day shift keeps the local wall clock across daylight saving`() {
        val display = readings(listOf(london), minutes = 1440, now = Instant.parse("2026-03-07T17:00:00Z"), localZone = newYork)
        assertEquals("Tomorrow 12:00 PM", display.readout)
        assertEquals("4:00", display.rows[1].clockDigits)
    }

    @Test
    fun `a half-hour zone`() {
        val row = readings(listOf(kolkata)).rows[1]
        assertEquals("5:12", row.clockDigits)
        assertEquals("AM", row.meridiem)
        assertEquals("13.5 hours ahead", row.offsetPhrase)
        assertEquals("India Standard Time (Kolkata, Mumbai) · next day", row.zoneLine)
    }

    @Test
    fun `a code label keeps the code and shows only the cities`() {
        val row = readings(listOf(easternTime)).rows[1]
        assertEquals("ET (Eastern Time)", row.placeName)
        assertEquals("New York, Toronto", row.zoneLine)
        assertEquals(easternTime.id, row.id)
    }

    @Test
    fun `a row matches the converter result band`() {
        val converted = ConverterPresenter()
            .displayState("3:42pm Los Angeles in Tokyo", winterAfternoon, losAngeles).convertedDisplay
        assertNotNull(converted)
        val row = readings(listOf(tokyo)).rows[1]
        assertEquals(converted.targetClockDigits, row.clockDigits)
        assertEquals(converted.targetMeridiem, row.meridiem)
        assertEquals(converted.targetZoneLine, row.zoneLine)
        assertEquals(converted.offsetPhrase, row.offsetPhrase)
    }

    @Test
    fun `a stale identifier is skipped`() {
        val stale = place("Mars/Olympus_Mons", "Olympus Mons")
        assertEquals(listOf("Los Angeles (local)", "London"), readings(listOf(stale, london)).rows.map { it.placeName })
    }

    @Test
    fun `offset descriptions drop zero parts`() {
        assertNull(WorldClockFormatting.offsetDescription(0))
        assertEquals("+5 h", WorldClockFormatting.offsetDescription(300))
        assertEquals("+1 d 15 min", WorldClockFormatting.offsetDescription(1455))
        assertEquals("−1 d", WorldClockFormatting.offsetDescription(-1440))
    }
}
