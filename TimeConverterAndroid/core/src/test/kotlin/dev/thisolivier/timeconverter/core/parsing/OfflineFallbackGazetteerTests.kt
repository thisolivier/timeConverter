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

    /** Item 34b: the chips for a split name say which place, and write back a form that resolves to that zone. */
    @Test
    fun `a split name carries a label and a typed form per zone`() {
        val portland = assertIs<ZoneResolution.Ambiguous>(ZoneResolverChain.standard.resolve("portland")).candidates
        assertEquals(listOf("Portland, Oregon", "Portland, Maine"), portland.map { it.pickerLabel })
        assertEquals(listOf("Portland Oregon", "Portland Maine"), portland.map { it.pickerTypedForm })
        for ((name, identifiers) in entries) {
            if (identifiers.size < 2) continue
            val choices = OfflineFallbackGazetteer.bundledChoices[name].orEmpty()
            assertEquals(identifiers.size, choices.size, name)
            for ((identifier, choice) in identifiers.zip(choices)) {
                val resolved = assertIs<ZoneResolution.Resolved>(ZoneResolverChain.standard.resolve(choice.typedForm.lowercase()), "$name → ${choice.label}")
                assertEquals(identifier, resolved.zone.zone.id, "$name → ${choice.label}")
            }
        }
    }

    /** Item 34c: a gazetteer place echoes under its own name; the zone it maps to stays on the zone line. */
    @Test
    fun `a place keeps its own name and an explicit display wins over re-casing`() {
        val rows = listOf(
            "porto" to "Porto", "rio de janeiro" to "Rio de Janeiro", "st john's antigua" to "St John's, Antigua",
            "portland oregon" to "Portland, Oregon", "washington dc" to "Washington, DC", "dc" to "DC",
            "us virgin islands" to "US Virgin Islands", "isle of wight" to "Isle of Wight", "mar del plata" to "Mar del Plata", "tonga" to "Tonga",
        )
        for ((token, expected) in rows) {
            val resolved = assertIs<ZoneResolution.Resolved>(ZoneResolverChain.standard.resolve(token), token).zone
            assertEquals(ZoneMatchSource.OfflineFallbackList, resolved.matchSource, token)
            assertEquals(expected, resolved.displayName, token)
        }
        for ((name, display) in OfflineFallbackGazetteer.bundledDisplayNames) {
            assertTrue(name in entries, "display for unknown entry $name")
            assertTrue(display != ZoneTokenDisplay.placeName(name), "redundant display for $name")
        }
    }

    @Test
    fun `place-name casing keeps joining particles lowercase after the first word`() {
        val rows = listOf(
            "porto" to "Porto", "rio de janeiro" to "Rio de Janeiro", "st john's" to "St John's",
            "stratford upon avon" to "Stratford upon Avon", "the hague" to "The Hague",
            "trinidad and tobago" to "Trinidad and Tobago", "washington d.c." to "Washington D.C.",
            "la paz" to "La Paz", "mar del plata" to "Mar del Plata",
        )
        for ((token, expected) in rows) assertEquals(expected, ZoneTokenDisplay.placeName(token), token)
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
