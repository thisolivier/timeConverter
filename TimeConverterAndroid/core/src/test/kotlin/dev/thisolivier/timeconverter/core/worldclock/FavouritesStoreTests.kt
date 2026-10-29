package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import dev.thisolivier.timeconverter.core.presentation.ConverterPresenter
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The store and what the star stores — twins of Swift `FavouritesStoreTests` / `FavouriteDestinationTests`. */
class FavouritesStoreTests {
    private val london = FavouriteDestination("Europe/London", ZoneLabel.Place("London", isDeviceLocal = false))
    private val newYork = FavouriteDestination("America/New_York", ZoneLabel.Place("New York", isDeviceLocal = false))
    private val easternTime = FavouriteDestination("America/New_York", ZoneLabel.Abbreviation("ET", "Eastern Time"))
    private val backing = InMemoryKeyValueBacking()

    @Test
    fun `starts empty`() {
        assertTrue(FavouritesStore(backing).favourites.isEmpty())
    }

    @Test
    fun `toggle adds in insertion order then removes`() {
        val changes = mutableListOf<List<FavouriteDestination>>()
        val store = FavouritesStore(backing) { changes.add(it) }
        store.toggle(london)
        store.toggle(newYork)
        assertEquals(listOf(london, newYork), store.favourites)
        assertTrue(store.isFavourite(london))
        store.toggle(london)
        assertEquals(listOf(newYork), store.favourites)
        assertFalse(store.isFavourite(london))
        assertEquals(3, changes.size)
    }

    @Test
    fun `same zone with a different label is a second favourite`() {
        val store = FavouritesStore(backing)
        store.toggle(newYork)
        store.toggle(easternTime)
        assertEquals(2, store.favourites.size)
        assertNotEquals(newYork.id, easternTime.id)
        assertFalse(store.isFavourite(FavouriteDestination("America/New_York", ZoneLabel.Place("Toronto", false))))
    }

    @Test
    fun `persists across instances and remove persists too`() {
        FavouritesStore(backing).toggle(easternTime)
        FavouritesStore(backing).toggle(london)
        assertEquals(listOf(easternTime, london), FavouritesStore(backing).favourites)
        FavouritesStore(backing).remove(easternTime)
        assertEquals(listOf(london), FavouritesStore(backing).favourites)
        FavouritesStore(backing).replaceAll(listOf(newYork, london))
        assertEquals(listOf(newYork, london), FavouritesStore(backing).favourites)
    }

    @Test
    fun `unreadable data degrades to no favourites`() {
        backing.putString(FavouritesStore.DEFAULTS_KEY, "not json")
        assertTrue(FavouritesStore(backing).favourites.isEmpty())
    }

    /** Swift's synthesized Codable shape, so both platforms store the same JSON. */
    @Test
    fun `json is swift's codable shape and round-trips`() {
        val encoded = FavouritesStore.encode(listOf(london, easternTime))
        assertEquals(
            """[{"timeZoneIdentifier":"Europe/London","label":{"place":{"name":"London","isDeviceLocal":false}}},""" +
                """{"timeZoneIdentifier":"America/New_York","label":{"abbreviation":{"code":"ET","expandedName":"Eastern Time"}}}]""",
            encoded,
        )
        assertEquals(listOf(london, easternTime), FavouritesStore.decode(encoded))
    }

    @Test
    fun `ids match the swift rule`() {
        assertEquals("Europe/London|place:London", london.id)
        assertEquals("America/New_York|code:ET:Eastern Time", easternTime.id)
        assertEquals("UTC|place:UTC:local", FavouriteDestination("UTC", ZoneLabel.Place("UTC", true)).id)
    }

    @Test
    fun `the converter's target is favouritable unless it is local`() {
        val presenter = ConverterPresenter()
        val now = Instant.parse("2026-01-15T12:00:00Z")
        val localZone = ZoneId.of("America/Los_Angeles")
        assertEquals(london, presenter.displayState("12pm ET in London", now, localZone).convertedDisplay?.favouritableTarget)
        assertEquals(easternTime, presenter.displayState("9am London in ET", now, localZone).convertedDisplay?.favouritableTarget)
        val localTarget = presenter.displayState("7pm East Coast", now, localZone).convertedDisplay
        assertNotNull(localTarget)
        assertNull(localTarget.favouritableTarget)
    }

    @Test
    fun `resolving a typed zone matches what the star stores`() {
        assertEquals(
            FavouriteDestination("Europe/Lisbon", ZoneLabel.Place("Lisbon", false)),
            FavouriteDestination.resolvingTypedZone("Portugal"),
        )
        assertNull(FavouriteDestination.resolvingTypedZone("CST"), "ambiguous zones are skipped")
        assertNull(FavouriteDestination.resolvingTypedZone("Lodnon"), "unknown zones are skipped")
    }

    @Test
    fun `a code favourite recovers its curated cities`() {
        val chicago = FavouriteDestination("America/Chicago", ZoneLabel.Abbreviation("CST", "Central Time"))
        val zone = chicago.resolvedZone
        assertNotNull(zone)
        assertEquals(listOf("Chicago", "Dallas"), zone.representativeCities)
        assertEquals(chicago.label, zone.label)
        assertNull(FavouriteDestination("Mars/Olympus_Mons", ZoneLabel.Place("Olympus Mons", false)).resolvedZone)
    }
}
