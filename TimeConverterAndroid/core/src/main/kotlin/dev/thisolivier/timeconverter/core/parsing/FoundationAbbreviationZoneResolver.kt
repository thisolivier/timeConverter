package dev.thisolivier.timeconverter.core.parsing

/**
 * Step 2 — Foundation's abbreviation dictionary (PST, EST, GMT, JST, …). Port
 * of Swift `FoundationAbbreviationZoneResolver`.
 *
 * The JVM has no `TimeZone.abbreviationDictionary` (`java.time` deliberately
 * refuses abbreviations, and `ZoneId.SHORT_IDS` is a different, older list), so
 * the dictionary is a static snapshot: [FoundationAbbreviationSnapshot].
 */
object FoundationAbbreviationZoneResolver : ZoneResolver {
    override val matchSource = ZoneMatchSource.FoundationAbbreviation

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> {
        val abbreviation = normalizedZoneToken.uppercase()
        val identifier = FoundationAbbreviationSnapshot.identifiersByAbbreviation[abbreviation] ?: return emptyList()
        return listOf(
            ZoneCandidate(identifier, matchSource, FoundationAbbreviationDisplayTable.displaysByAbbreviation[abbreviation])
        )
    }

    /** All abbreviation-shaped, which keeps the suggester from offering `cet` for a mistyped code. */
    override val vocabulary: List<ZoneVocabularyEntry>
        get() = FoundationAbbreviationSnapshot.identifiersByAbbreviation.keys.map {
            ZoneVocabularyEntry(it.lowercase(), ZoneVocabularyEntry.Shape.Abbreviation, matchSource)
        }
}

/**
 * A snapshot of Foundation's `TimeZone.abbreviationDictionary`, every entry,
 * captured 2026-10-28 on macOS 26.2 (the iOS 26 dictionary is the same
 * Foundation table). Keys are uppercase, as in Foundation. Refresh by printing
 * the dictionary from a Swift script if a future OS changes it.
 */
object FoundationAbbreviationSnapshot {
    val identifiersByAbbreviation: Map<String, String> = linkedMapOf(
        "ADT" to "America/Halifax",
        "AKDT" to "America/Juneau",
        "AKST" to "America/Juneau",
        "ART" to "America/Argentina/Buenos_Aires",
        "AST" to "America/Halifax",
        "BDT" to "Asia/Dhaka",
        "BRST" to "America/Sao_Paulo",
        "BRT" to "America/Sao_Paulo",
        "BST" to "Europe/London",
        "CAT" to "Africa/Harare",
        "CDT" to "America/Chicago",
        "CEST" to "Europe/Paris",
        "CET" to "Europe/Paris",
        "CLST" to "America/Santiago",
        "CLT" to "America/Santiago",
        "COT" to "America/Bogota",
        "CST" to "America/Chicago",
        "EAT" to "Africa/Addis_Ababa",
        "EDT" to "America/New_York",
        "EEST" to "Europe/Athens",
        "EET" to "Europe/Athens",
        "EST" to "America/New_York",
        "GMT" to "GMT",
        "GST" to "Asia/Dubai",
        "HKT" to "Asia/Hong_Kong",
        "HST" to "Pacific/Honolulu",
        "ICT" to "Asia/Bangkok",
        "IRST" to "Asia/Tehran",
        "IST" to "Asia/Kolkata",
        "JST" to "Asia/Tokyo",
        "KST" to "Asia/Seoul",
        "MDT" to "America/Denver",
        "MSD" to "Europe/Moscow",
        "MSK" to "Europe/Moscow",
        "MST" to "America/Phoenix",
        "NDT" to "America/St_Johns",
        "NST" to "America/St_Johns",
        "NZDT" to "Pacific/Auckland",
        "NZST" to "Pacific/Auckland",
        "PDT" to "America/Los_Angeles",
        "PET" to "America/Lima",
        "PHT" to "Asia/Manila",
        "PKT" to "Asia/Karachi",
        "PST" to "America/Los_Angeles",
        "SGT" to "Asia/Singapore",
        "TRT" to "Europe/Istanbul",
        "UTC" to "UTC",
        "WAT" to "Africa/Lagos",
        "WEST" to "Europe/Lisbon",
        "WET" to "Europe/Lisbon",
        "WIT" to "Asia/Jakarta",
    )
}

/**
 * Expanded names for the abbreviations worth expanding (item 13) — verbatim
 * from Swift `FoundationAbbreviationDisplayTable`. Deliberately partial: an
 * abbreviation absent here echoes as its identifier's city.
 */
object FoundationAbbreviationDisplayTable {
    private fun display(name: String, vararg cities: String) = AbbreviationDisplay(name, cities.toList())

    val displaysByAbbreviation: Map<String, AbbreviationDisplay> = linkedMapOf(
        // North America.
        "EST" to display("Eastern Standard Time", "New York", "Toronto"),
        "EDT" to display("Eastern Daylight Time", "New York", "Toronto"),
        "CDT" to display("Central Daylight Time", "Chicago", "Dallas"),
        "MST" to display("Mountain Standard Time", "Denver", "Calgary"),
        "MDT" to display("Mountain Daylight Time", "Denver", "Calgary"),
        "PST" to display("Pacific Standard Time", "Los Angeles", "Vancouver"),
        "PDT" to display("Pacific Daylight Time", "Los Angeles", "Vancouver"),
        "AKST" to display("Alaska Standard Time", "Anchorage"),
        "AKDT" to display("Alaska Daylight Time", "Anchorage"),
        "HST" to display("Hawaii Standard Time", "Honolulu"),
        "AST" to display("Atlantic Standard Time", "Halifax"),
        "ADT" to display("Atlantic Daylight Time", "Halifax"),

        // Europe. No cities for GMT/UTC: they are the reference, not a place.
        "GMT" to display("Greenwich Mean Time"),
        "UTC" to display("Coordinated Universal Time"),
        "BST" to display("British Summer Time", "London"),
        "WEST" to display("Western European Summer Time", "Lisbon"),

        // Asia and the Pacific.
        "JST" to display("Japan Standard Time", "Tokyo"),
        "KST" to display("Korea Standard Time", "Seoul"),
        "HKT" to display("Hong Kong Time", "Hong Kong"),
        "SGT" to display("Singapore Time", "Singapore"),
        "NZST" to display("New Zealand Standard Time", "Auckland"),
        "NZDT" to display("New Zealand Daylight Time", "Auckland"),

        // South America.
        "BRT" to display("Brasília Time", "São Paulo"),
        "ART" to display("Argentina Time", "Buenos Aires"),
    )
}
