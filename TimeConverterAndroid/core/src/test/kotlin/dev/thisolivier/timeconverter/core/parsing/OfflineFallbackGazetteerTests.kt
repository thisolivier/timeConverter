package dev.thisolivier.timeconverter.core.parsing

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * The gazetteer is read from the Swift core's resource on the classpath, and
 * every entry is reachable. Mirrors Swift `OfflineFallbackGazetteerTests` and
 * `GazetteerCoverageTests`.
 */
class OfflineFallbackGazetteerTests {
    private val entries = OfflineFallbackGazetteer.bundledEntries

    @Test
    fun `the bundled file is on the classpath and decodes`() {
        assertTrue(entries.size > 3000, "fallback-cities.json missing from the classpath? (${entries.size} entries)")
        assertEquals(listOf("Europe/Lisbon"), entries["porto"])
        assertTrue(entries.keys.all { it == it.lowercase() })
    }

    /**
     * An earlier step answering a gazetteer name makes it unreachable. The one
     * known Android exception is `kolkata`: `java.time` ships the canonical
     * `Asia/Kolkata` (Apple only the link `Asia/Calcutta`), so step 3 answers
     * it first — with the very zone the gazetteer names.
     */
    @Test
    fun `every gazetteer name is answered by the gazetteer itself`() {
        val chain = ZoneResolverChain.standard
        val shadowed = entries.keys.filter { name ->
            when (val resolution = chain.resolve(name)) {
                is ZoneResolution.Resolved -> resolution.zone.matchSource != ZoneMatchSource.OfflineFallbackList
                is ZoneResolution.Ambiguous -> resolution.candidates.any { it.matchSource != ZoneMatchSource.OfflineFallbackList }
                ZoneResolution.Unknown -> true
            }
        }
        assertEquals(listOf("kolkata"), shadowed)
        val kolkata = assertIs<ZoneResolution.Resolved>(chain.resolve("kolkata")).zone
        assertEquals(entries.getValue("kolkata"), listOf(kolkata.zone.id))
    }

    @Test
    fun `a name split across zones prompts`() {
        val sanJose = assertIs<ZoneResolution.Ambiguous>(ZoneResolverChain.standard.resolve("san jose")).candidates
        assertTrue(sanJose.size > 1)
    }

    @Test
    fun `a malformed file degrades to an empty table`() {
        assertTrue(OfflineFallbackGazetteer.decodeEntries("not json").isEmpty())
        val decoded = OfflineFallbackGazetteer.decodeEntries(
            """{"version":1,"entries":[{"name":"Atlantis","timeZoneIdentifiers":[]},{"name":"Prto","timeZoneIdentifiers":["Europe/Lisbon"],"comment":"x"}]}"""
        )
        assertEquals(mapOf("prto" to listOf("Europe/Lisbon")), decoded)
    }
}
