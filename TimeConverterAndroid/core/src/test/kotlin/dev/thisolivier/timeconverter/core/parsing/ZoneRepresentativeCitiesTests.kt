package dev.thisolivier.timeconverter.core.parsing

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Item 21's cities, read backwards from the abbreviation tables. Mirrors the city-index rows of Swift `ZoneLineTests`. */
class ZoneRepresentativeCitiesTests {
    @Test
    fun `curated zones get their curated cities, the richer list winning`() {
        assertEquals(listOf("New York", "Toronto"), ZoneRepresentativeCities.cities("America/New_York"))
        assertEquals(listOf("Sydney", "Melbourne"), ZoneRepresentativeCities.cities("Australia/Sydney"))
        assertEquals(listOf("São Paulo"), ZoneRepresentativeCities.cities("America/Sao_Paulo"))
    }

    @Test
    fun `an entry that does not name the zone's own city is rejected`() {
        // Foundation maps MST to Phoenix, whose curated cities (Denver, Calgary) observe DST.
        assertFalse(ZoneRepresentativeCities.isSelfConsistent(listOf("Denver", "Calgary"), "America/Phoenix"))
        assertEquals(listOf("Phoenix"), ZoneRepresentativeCities.cities("America/Phoenix"))
        // AKST maps to Juneau, curated as Anchorage.
        assertEquals(listOf("Juneau"), ZoneRepresentativeCities.cities("America/Juneau"))
    }

    @Test
    fun `uncurated zones fall back to their own city and the list is never empty`() {
        assertEquals(listOf("Kathmandu"), ZoneRepresentativeCities.cities("Asia/Kathmandu"))
        assertTrue(ZoneRepresentativeCities.curatedCitiesByIdentifier.values.all { it.isNotEmpty() })
    }
}
