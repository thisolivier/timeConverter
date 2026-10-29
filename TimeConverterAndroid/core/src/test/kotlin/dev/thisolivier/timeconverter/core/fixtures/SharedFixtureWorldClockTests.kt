package dev.thisolivier.timeconverter.core.fixtures

import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import dev.thisolivier.timeconverter.core.worldclock.FavouriteDestination
import dev.thisolivier.timeconverter.core.worldclock.WorldClock
import dev.thisolivier.timeconverter.core.worldclock.WorldClockDisplay
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The world-clock half of the shared contract (item 32): every case of
 * `fixtures/world-clock-cases.json`, replayed from its own favourites, offset,
 * clock and zone through the Kotlin `WorldClock`, compared exactly — the
 * readout, the signed offset and every row's slots. The twin of Swift
 * `SharedWorldClockFixtureTests`' replay mode. The ship gate
 * (`scripts/lib/parity-gate.sh`) requires this class to run clean.
 */
class SharedFixtureWorldClockTests {
    private val file = SharedFixtures.loadWorldClock()

    @Test
    fun `world clock agrees with every fixture exactly`() {
        val failures = file.cases.mapNotNull { case ->
            val actual = expected(render(case))
            if (actual == case.expected) null
            else "${case.id}:\n    expected ${case.expected}\n    actual   $actual"
        }
        assertTrue(
            failures.isEmpty(),
            "World clock disagrees with ${failures.size} of ${file.cases.size} fixture(s):\n" + failures.joinToString("\n"),
        )
    }

    /** The slots the file does not spell out: ids and the favourite each row carries. */
    @Test
    fun `rows carry their favourite and its id, the local row neither`() {
        for (case in file.cases) {
            val favourites = case.favourites.map(::destination)
            val rows = render(case).rows
            assertEquals("local", rows.first().id, case.id)
            assertEquals(null, rows.first().favourite, case.id)
            assertEquals(favourites, rows.drop(1).map { it.favourite }, case.id)
            assertEquals(favourites.map { it.id }, rows.drop(1).map { it.id }, case.id)
        }
    }

    @Test
    fun `fixture file loads, ids are unique and the spec's cases are present`() {
        assertEquals(1, file.schemaVersion)
        val identifiers = file.cases.map { it.id }
        assertEquals(identifiers.size, identifiers.toSet().size)
        assertTrue(file.cases.size >= 11, "world-clock fixture file shrank to ${file.cases.size} cases")
        assertTrue(file.cases.any { it.offsetSeconds < 0 } && file.cases.any { it.offsetSeconds > 0 })
        assertTrue(file.cases.any { case -> case.favourites.any { it.labelKind == "code" } })
    }

    private fun render(case: WorldClockCase): WorldClockDisplay = WorldClock.readings(
        favourites = case.favourites.map(::destination),
        offsetMinutes = case.offsetSeconds / 60,
        now = Instant.parse(case.now),
        localZone = ZoneId.of(case.localZone),
    )

    private fun destination(favourite: WorldClockFixtureFavourite): FavouriteDestination {
        val label = if (favourite.labelKind == "code") {
            ZoneLabel.Abbreviation(favourite.code!!, favourite.expandedName!!)
        } else {
            ZoneLabel.Place(favourite.name!!, isDeviceLocal = false)
        }
        return FavouriteDestination(favourite.timeZoneIdentifier, label)
    }

    private fun expected(display: WorldClockDisplay) = ExpectedWorldClock(
        readout = display.readout,
        offsetDescription = display.offsetDescription,
        rows = display.rows.map { row ->
            ExpectedWorldClockRow(
                isLocal = row.isLocal,
                placeName = row.placeName,
                clockDigits = row.clockDigits,
                meridiem = row.meridiem,
                zoneLine = row.zoneLine,
                offsetPhrase = row.offsetPhrase,
            )
        },
    )
}
