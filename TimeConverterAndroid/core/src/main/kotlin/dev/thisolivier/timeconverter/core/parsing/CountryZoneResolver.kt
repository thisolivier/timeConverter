package dev.thisolivier.timeconverter.core.parsing

/**
 * Step 4 — the country table. Port of Swift `CountryZoneResolver`: a national
 * clock resolves (`japan`, `portugal`), a country without one returns every
 * zone and the chain turns that into a picker (`usa`).
 */
object CountryZoneResolver : ZoneResolver {
    override val matchSource = ZoneMatchSource.CountryTable

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> =
        CountryZoneTable.zonesByCountryName[normalizedZoneToken]?.candidateIdentifiers.orEmpty()
            .map { ZoneCandidate(it, matchSource) }

    /** Place-shaped, so the suggester offers them — `portgual` → `Portugal`. */
    override val vocabulary: List<ZoneVocabularyEntry>
        get() = CountryZoneTable.zonesByCountryName.keys.map {
            ZoneVocabularyEntry(it, ZoneVocabularyEntry.Shape.PlaceName, matchSource)
        }
}
