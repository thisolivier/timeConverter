package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Item 36 — mirrors Swift `SavedCitiesWidgetSupportTests`. */
class SavedCitiesWidgetSupportTests {
    @Test
    fun `rows are local plus at most five favourites`() {
        val favourites = listOf("Europe/London", "Asia/Tokyo", "Europe/Paris", "Australia/Sydney", "Asia/Kolkata", "America/Lima")
            .map { FavouriteDestination(it, ZoneLabel.Place(it.substringAfter('/'), isDeviceLocal = false)) }
        val display = WorldClock.readings(favourites, 0, Instant.parse("2026-01-15T12:00:00Z"), ZoneId.of("America/Los_Angeles"))
        val rows = SavedCitiesWidgetSupport.rows(display)
        assertEquals(6, rows.size)
        assertTrue(rows.first().isLocal)
        assertEquals(listOf("London", "Tokyo", "Paris", "Sydney", "Kolkata"), rows.drop(1).map { it.placeName })
    }
}
