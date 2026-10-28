package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ZoneDisplayName
import java.time.ZoneId

/**
 * INTERIM. The interim parser's whole vocabulary: the Swift alias table
 * (`AliasZoneTable`, copied verbatim including the two ambiguous codes `cst`
 * and `ist`), a handful of the Foundation abbreviations the Swift chain gets
 * from `TimeZone.abbreviationDictionary`, and the tz database's own city
 * names. Replaced wholesale by the parser port (backlog 24b).
 */
object InterimZoneTable {
    /** One meaning of an alias. Port of Swift `AliasZoneMeaning`. */
    data class AliasMeaning(
        val timeZoneIdentifier: String,
        val expandedName: String,
        val representativeCities: List<String>,
    )

    /** A did-you-mean candidate source. Port of Swift `ZoneVocabularyEntry`, minus chain levels. */
    data class VocabularyEntry(val token: String, val isAbbreviation: Boolean) {
        /** `PST` for a code, `New York` for a place — the chip's text. */
        val suggestionLabel: String
            get() = if (isAbbreviation) token.uppercase()
            else token.split(' ').joinToString(" ") { word -> word.replaceFirstChar { it.uppercaseChar() } }
    }

    private fun meaning(identifier: String, name: String, vararg cities: String) =
        AliasMeaning(identifier, name, cities.toList())

    val meaningsByAlias: Map<String, List<AliasMeaning>> = mapOf(
        // Ambiguous by design — every meaning is offered as a P4 chip.
        "cst" to listOf(
            meaning("America/Chicago", "Central Time", "Chicago", "Dallas"),
            meaning("Asia/Shanghai", "China Standard Time", "Shanghai", "Beijing"),
        ),
        "ist" to listOf(
            meaning("Asia/Kolkata", "India Standard Time", "Kolkata", "Mumbai"),
            meaning("Europe/Dublin", "Irish Standard Time", "Dublin"),
        ),
        "et" to listOf(meaning("America/New_York", "Eastern Time", "New York", "Toronto")),
        "ct" to listOf(meaning("America/Chicago", "Central Time", "Chicago", "Dallas")),
        "mt" to listOf(meaning("America/Denver", "Mountain Time", "Denver", "Calgary")),
        "pt" to listOf(meaning("America/Los_Angeles", "Pacific Time", "Los Angeles", "Vancouver")),
        "akt" to listOf(meaning("America/Anchorage", "Alaska Time", "Anchorage")),
        "nyc" to listOf(meaning("America/New_York", "Eastern Time", "New York")),
        "east coast" to listOf(meaning("America/New_York", "Eastern Time", "New York", "Toronto")),
        "west coast" to listOf(meaning("America/Los_Angeles", "Pacific Time", "Los Angeles", "Vancouver")),
        "uk" to listOf(meaning("Europe/London", "UK Time", "London")),
        "gb" to listOf(meaning("Europe/London", "UK Time", "London")),
        "cet" to listOf(meaning("Europe/Paris", "Central European Time", "Paris", "Berlin")),
        "cest" to listOf(meaning("Europe/Paris", "Central European Summer Time", "Paris", "Berlin")),
        "eet" to listOf(meaning("Europe/Athens", "Eastern European Time", "Athens", "Helsinki")),
        "eest" to listOf(meaning("Europe/Athens", "Eastern European Summer Time", "Athens", "Helsinki")),
        "wet" to listOf(meaning("Europe/Lisbon", "Western European Time", "Lisbon")),
        "west" to listOf(meaning("Europe/Lisbon", "Western European Summer Time", "Lisbon")),
        "aet" to listOf(meaning("Australia/Sydney", "Australian Eastern Time", "Sydney")),
        "aest" to listOf(meaning("Australia/Sydney", "Australian Eastern Standard Time", "Sydney", "Melbourne")),
        "aedt" to listOf(meaning("Australia/Sydney", "Australian Eastern Daylight Time", "Sydney", "Melbourne")),
        "acst" to listOf(meaning("Australia/Adelaide", "Australian Central Standard Time", "Adelaide")),
        "acdt" to listOf(meaning("Australia/Adelaide", "Australian Central Daylight Time", "Adelaide")),
        "awst" to listOf(meaning("Australia/Perth", "Australian Western Standard Time", "Perth")),
        // INTERIM stand-ins for the Foundation abbreviation level.
        "pst" to listOf(meaning("America/Los_Angeles", "Pacific Standard Time", "Los Angeles", "Vancouver")),
        "est" to listOf(meaning("America/New_York", "Eastern Standard Time", "New York", "Toronto")),
        "gmt" to listOf(meaning("GMT", "Greenwich Mean Time")),
        "utc" to listOf(meaning("UTC", "Coordinated Universal Time")),
    )

    private val geographicAreas = setOf(
        "Africa", "America", "Antarctica", "Asia", "Atlantic", "Australia", "Europe", "Indian", "Pacific",
    )

    /**
     * `new york` → `America/New_York`, built once from the live database.
     * Geographic areas only, and no all-caps legacy aliases (`Australia/NSW`),
     * which would otherwise turn up as did-you-mean chips.
     */
    val cityIdentifiersByName: Map<String, String> = ZoneId.getAvailableZoneIds()
        .filter { identifier ->
            val lastComponent = identifier.substringAfterLast('/')
            identifier.substringBefore('/') in geographicAreas && lastComponent != lastComponent.uppercase()
        }
        .sorted()
        .associateBy { ZoneDisplayName.forIdentifier(it).lowercase() }

    /**
     * Everything the suggester may offer. Multi-word aliases are phrases, so
     * they count as places (same rule as Swift `AliasZoneResolver.vocabulary`).
     */
    val vocabulary: List<VocabularyEntry> by lazy {
        meaningsByAlias.keys.map { VocabularyEntry(it, isAbbreviation = !it.contains(' ')) } +
            cityIdentifiersByName.keys.map { VocabularyEntry(it, isAbbreviation = false) }
    }
}
