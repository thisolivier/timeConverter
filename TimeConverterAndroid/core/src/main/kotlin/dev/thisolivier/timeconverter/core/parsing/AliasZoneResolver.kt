package dev.thisolivier.timeconverter.core.parsing

/**
 * Step 1 — the hand-rolled alias table. Port of Swift `AliasZoneResolver`.
 *
 * Covers the DST-neutral and colloquial forms Foundation has no entry for
 * (`ET`, `PT`, `UK`, `AEST`…) and deliberately *overrides* step 2 for codes
 * that mean two places: `CST` and `IST` list both meanings, so the user gets a
 * picker instead of a silent guess.
 */
object AliasZoneResolver : ZoneResolver {
    override val matchSource = ZoneMatchSource.AliasTable

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> =
        AliasZoneTable.meaningsByAlias[normalizedZoneToken].orEmpty().map {
            ZoneCandidate(it.timeZoneIdentifier, matchSource, it.display)
        }

    /** Codes are abbreviation-shaped; the multi-word colloquialisms (`east coast`) are phrases, so places. */
    override val vocabulary: List<ZoneVocabularyEntry>
        get() = AliasZoneTable.meaningsByAlias.keys.map { alias ->
            ZoneVocabularyEntry(
                token = alias,
                shape = if (alias.contains(' ')) ZoneVocabularyEntry.Shape.PlaceName else ZoneVocabularyEntry.Shape.Abbreviation,
                matchSource = matchSource,
            )
        }
}

/** One meaning of an alias: the zone, plus the expanded name the echo shows (item 13). */
data class AliasZoneMeaning(val timeZoneIdentifier: String, val display: AbbreviationDisplay)

/**
 * Editorial choices, versioned in code — copied verbatim from Swift
 * `AliasZoneTable` (same keys, order, names and cities).
 */
object AliasZoneTable {
    private fun meaning(identifier: String, name: String, vararg cities: String) =
        AliasZoneMeaning(identifier, AbbreviationDisplay(name, cities.toList()))

    val meaningsByAlias: Map<String, List<AliasZoneMeaning>> = linkedMapOf(
        // Ambiguous by design — every listed meaning is offered to the user.
        "cst" to listOf(
            meaning("America/Chicago", "Central Time", "Chicago", "Dallas"),
            meaning("Asia/Shanghai", "China Standard Time", "Shanghai", "Beijing"),
        ),
        "ist" to listOf(
            meaning("Asia/Kolkata", "India Standard Time", "Kolkata", "Mumbai"),
            meaning("Europe/Dublin", "Irish Standard Time", "Dublin"),
        ),

        // DST-neutral North American forms.
        "et" to listOf(meaning("America/New_York", "Eastern Time", "New York", "Toronto")),
        "ct" to listOf(meaning("America/Chicago", "Central Time", "Chicago", "Dallas")),
        "mt" to listOf(meaning("America/Denver", "Mountain Time", "Denver", "Calgary")),
        "pt" to listOf(meaning("America/Los_Angeles", "Pacific Time", "Los Angeles", "Vancouver")),
        "akt" to listOf(meaning("America/Anchorage", "Alaska Time", "Anchorage")),
        "nyc" to listOf(meaning("America/New_York", "Eastern Time", "New York")),

        // Colloquial US coasts.
        "east coast" to listOf(meaning("America/New_York", "Eastern Time", "New York", "Toronto")),
        "west coast" to listOf(meaning("America/Los_Angeles", "Pacific Time", "Los Angeles", "Vancouver")),

        // European colloquialisms.
        "uk" to listOf(meaning("Europe/London", "UK Time", "London")),
        "gb" to listOf(meaning("Europe/London", "UK Time", "London")),
        "cet" to listOf(meaning("Europe/Paris", "Central European Time", "Paris", "Berlin")),
        "cest" to listOf(meaning("Europe/Paris", "Central European Summer Time", "Paris", "Berlin")),
        "eet" to listOf(meaning("Europe/Athens", "Eastern European Time", "Athens", "Helsinki")),
        "eest" to listOf(meaning("Europe/Athens", "Eastern European Summer Time", "Athens", "Helsinki")),
        "wet" to listOf(meaning("Europe/Lisbon", "Western European Time", "Lisbon")),
        "west" to listOf(meaning("Europe/Lisbon", "Western European Summer Time", "Lisbon")),

        // Australian forms, none of which Foundation knows.
        "aet" to listOf(meaning("Australia/Sydney", "Australian Eastern Time", "Sydney")),
        "aest" to listOf(meaning("Australia/Sydney", "Australian Eastern Standard Time", "Sydney", "Melbourne")),
        "aedt" to listOf(meaning("Australia/Sydney", "Australian Eastern Daylight Time", "Sydney", "Melbourne")),
        "acst" to listOf(meaning("Australia/Adelaide", "Australian Central Standard Time", "Adelaide")),
        "acdt" to listOf(meaning("Australia/Adelaide", "Australian Central Daylight Time", "Adelaide")),
        "awst" to listOf(meaning("Australia/Perth", "Australian Western Standard Time", "Perth")),
    )
}
