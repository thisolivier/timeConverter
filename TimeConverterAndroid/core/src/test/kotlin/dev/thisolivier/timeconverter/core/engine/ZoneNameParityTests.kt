package dev.thisolivier.timeconverter.core.engine

import dev.thisolivier.timeconverter.core.fixtures.SharedFixtures
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Zone names agree with iOS exactly: `ZoneNames` renders from the Swift core's iOS-origin
 * snapshot (`zone-names.json`, on the classpath via the build), and every fixture zone line's
 * name — the part before ` (` on a place-labelled side — is that name, with no wildcard.
 */
class ZoneNameParityTests {
    @Test
    fun `snapshot is on the classpath and names the example zones as iOS does`() {
        assertTrue(ZoneNames.namesByIdentifier.size > 400, "zone-names.json missing from the classpath?")
        assertEquals("Eastern Time", ZoneNames.genericName(ZoneId.of("America/New_York")))
        assertEquals("United Kingdom Time", ZoneNames.genericName(ZoneId.of("Europe/London")))
        assertEquals("Australian Eastern Time", ZoneNames.genericName(ZoneId.of("Australia/Sydney")))
        assertEquals("India Standard Time", ZoneNames.genericName(ZoneId.of("Asia/Kolkata")))
    }

    @Test
    fun `an identifier the snapshot lacks falls back to its city name`() {
        // Etc/GMT+5 is a valid java.time zone that Apple's identifier list does not carry.
        assertTrue("Etc/GMT+5" !in ZoneNames.namesByIdentifier)
        assertEquals("GMT+5 Time", ZoneNames.genericName(ZoneId.of("Etc/GMT+5")))
    }

    @Test
    fun `every fixture zone line names its zone exactly as ZoneNames does`() {
        val conversions = SharedFixtures.load().cases.filter { it.expected.kind == "conversion" }
        val failures = conversions.flatMap { case ->
            val display = case.expected.display!!
            listOf(
                Triple("source", display.sourceZoneLine, case.expected.sourceZone!!),
                Triple("target", display.targetZoneLine, case.expected.targetZone!!),
            ).mapNotNull { (side, line, zone) ->
                if (!line.contains(" (")) return@mapNotNull null // abbreviation-labelled: cities only
                val expectedName = line.substringBefore(" (")
                val actualName = ZoneNames.genericName(ZoneId.of(zone))
                if (expectedName == actualName) null else "${case.id} $side ($zone): expected `$expectedName`, got `$actualName`"
            }
        }
        assertTrue(failures.isEmpty(), "Zone names disagree with the fixtures:\n" + failures.joinToString("\n"))
    }
}
