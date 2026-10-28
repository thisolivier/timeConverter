package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ZoneDisplayName
import java.text.Normalizer

/**
 * Which two or three cities stand for a zone — item 21's sub-line
 * (`Brasilia Standard Time (São Paulo)`). Port of Swift
 * `ZoneRepresentativeCities`: the two abbreviation tables read backwards.
 *
 * Self-consistency rule: an entry counts for a zone only when the zone's own
 * city is in it, so `MST` → `America/Phoenix` (cities Denver, Calgary) is
 * rejected and Phoenix falls back to its own name.
 */
object ZoneRepresentativeCities {
    const val MAXIMUM_CITY_COUNT = 3

    /** The curated list when there is a self-consistent one, else the identifier's own city. Never empty. */
    fun cities(timeZoneIdentifier: String): List<String> {
        val curated = curatedCitiesByIdentifier[timeZoneIdentifier]
            ?: return listOf(ZoneDisplayName.forIdentifier(timeZoneIdentifier))
        return curated.take(MAXIMUM_CITY_COUNT)
    }

    /**
     * Built once: alias table first, then the Foundation table, each in sorted
     * key order, a richer list beating a shorter one — so Sydney gets Sydney
     * *and* Melbourne from `aest`, deterministically.
     */
    val curatedCitiesByIdentifier: Map<String, List<String>> by lazy {
        val citiesByIdentifier = HashMap<String, List<String>>()
        for ((identifier, cities) in curatedEntries()) {
            if (cities.isEmpty() || !isSelfConsistent(cities, identifier)) continue
            if (cities.size > (citiesByIdentifier[identifier]?.size ?: 0)) citiesByIdentifier[identifier] = cities
        }
        citiesByIdentifier
    }

    private fun curatedEntries(): List<Pair<String, List<String>>> {
        val aliasEntries = AliasZoneTable.meaningsByAlias.keys.sorted().flatMap { alias ->
            AliasZoneTable.meaningsByAlias.getValue(alias).map { it.timeZoneIdentifier to it.display.representativeCities }
        }
        val foundationEntries = FoundationAbbreviationDisplayTable.displaysByAbbreviation.keys.sorted().mapNotNull { abbreviation ->
            val identifier = FoundationAbbreviationSnapshot.identifiersByAbbreviation[abbreviation] ?: return@mapNotNull null
            identifier to FoundationAbbreviationDisplayTable.displaysByAbbreviation.getValue(abbreviation).representativeCities
        }
        return aliasEntries + foundationEntries
    }

    /** True when the zone's own city is listed — compared ignoring case and diacritics (`São Paulo` = `Sao Paulo`). */
    fun isSelfConsistent(cities: List<String>, timeZoneIdentifier: String): Boolean {
        val ownCity = comparable(ZoneDisplayName.forIdentifier(timeZoneIdentifier))
        return cities.any { comparable(it) == ownCity }
    }

    private val combiningMarks = Regex("\\p{Mn}+")

    private fun comparable(cityName: String): String =
        combiningMarks.replace(Normalizer.normalize(cityName, Normalizer.Form.NFD), "").lowercase()
}
