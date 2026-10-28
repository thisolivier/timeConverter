package dev.thisolivier.timeconverter.core.parsing

import dev.thisolivier.timeconverter.core.engine.ZoneDisplayName
import java.time.ZoneId

/**
 * Step 3 — city match against the tz database itself. Port of Swift
 * `TimeZoneDatabaseCityResolver`: the final component of every area-prefixed
 * identifier, underscores as spaces (`new york` → `America/New_York`).
 *
 * Built from `ZoneId.getAvailableZoneIds()`. Two guards keep it to the cities
 * Apple's `TimeZone.knownTimeZoneIdentifiers` indexes:
 * - only identifiers under a real IANA area ([CITY_BEARING_AREAS]), so the
 *   legacy bare names (`Portugal`, `Japan`, `GB`) and `US/Pacific`, `Etc/GMT+5`
 *   never short-circuit the country table;
 * - minus [LEGACY_LINK_IDENTIFIERS], the tzdata "backward" links that
 *   `java.time` carries and Apple's list does not. Without them `buenos aires`
 *   would be ambiguous (`America/Buenos_Aires` + `America/Argentina/…`) and
 *   `nsw`, `saigon`, `dacca` would resolve here but not on iOS.
 *
 * Index values are lists: a future collision is an ambiguity, never a guess.
 */
object TimeZoneDatabaseCityResolver : ZoneResolver {
    override val matchSource = ZoneMatchSource.TimeZoneDatabaseCity

    override fun candidates(normalizedZoneToken: String): List<ZoneCandidate> =
        identifiersByCityName[normalizedZoneToken].orEmpty().map { ZoneCandidate(it, matchSource) }

    override val vocabulary: List<ZoneVocabularyEntry>
        get() = identifiersByCityName.keys.map {
            ZoneVocabularyEntry(it, ZoneVocabularyEntry.Shape.PlaceName, matchSource)
        }

    /** The canonical IANA areas; everything else in the list is a legacy alias or an offset bucket. */
    val CITY_BEARING_AREAS = setOf(
        "Africa", "America", "Antarctica", "Arctic", "Asia",
        "Atlantic", "Australia", "Europe", "Indian", "Pacific",
    )

    /**
     * Area-prefixed identifiers in `java.time` (tzdata 2026a, JDK 17) that
     * Apple's known-identifier list omits — diffed 2026-10-28 against macOS
     * 26.2. `Asia/Kolkata` is the one Java-only name kept: it is the canonical
     * identifier (Apple lists only the link `Asia/Calcutta`), and resolving it
     * here gives the same zone the Swift gazetteer gives for `kolkata`.
     */
    val LEGACY_LINK_IDENTIFIERS = setOf(
        "Africa/Asmera", "Africa/Timbuktu", "America/Argentina/ComodRivadavia", "America/Atka",
        "America/Buenos_Aires", "America/Catamarca", "America/Coral_Harbour", "America/Cordoba",
        "America/Ensenada", "America/Fort_Wayne", "America/Indianapolis", "America/Jujuy",
        "America/Knox_IN", "America/Louisville", "America/Mendoza", "America/Porto_Acre",
        "America/Rosario", "America/Virgin", "Asia/Ashkhabad", "Asia/Chungking",
        "Asia/Dacca", "Asia/Istanbul", "Asia/Macao", "Asia/Saigon",
        "Asia/Tel_Aviv", "Asia/Thimbu", "Asia/Ujung_Pandang", "Asia/Ulan_Bator",
        "Atlantic/Faeroe", "Atlantic/Jan_Mayen", "Australia/ACT", "Australia/Canberra",
        "Australia/LHI", "Australia/North", "Australia/NSW", "Australia/Queensland",
        "Australia/South", "Australia/Tasmania", "Australia/Victoria", "Australia/West",
        "Australia/Yancowinna", "Europe/Belfast", "Europe/Nicosia", "Europe/Tiraspol",
        "Pacific/Samoa", "Pacific/Yap",
    )

    /** Built once from whatever tz database the runtime ships. */
    val identifiersByCityName: Map<String, List<String>> by lazy {
        ZoneId.getAvailableZoneIds()
            .filter { isCityBearing(it) && it !in LEGACY_LINK_IDENTIFIERS }
            .groupBy { ZoneDisplayName.forIdentifier(it).lowercase() }
            .mapValues { (_, identifiers) -> identifiers.sorted() }
    }

    /** Area-prefixed (`Europe/London`) under a real area; bare names and `US/Pacific` are not cities. */
    fun isCityBearing(identifier: String): Boolean {
        val components = identifier.split('/').filter { it.isNotEmpty() }
        return components.size >= 2 && components[0] in CITY_BEARING_AREAS
    }
}
