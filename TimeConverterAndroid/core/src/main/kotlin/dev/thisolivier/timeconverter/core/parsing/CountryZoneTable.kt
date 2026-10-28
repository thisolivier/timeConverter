package dev.thisolivier.timeconverter.core.parsing

/**
 * What a country name resolves to — port of Swift `CountryZones`. Most
 * countries have a national clock even when the tz database splits them; only
 * those with none prompt.
 */
sealed interface CountryZones {
    /** The clock on the country's mainland street. One candidate, so it resolves directly. */
    data class Canonical(val identifier: String) : CountryZones

    /** No single national clock: every zone is offered, in table order (most populous first). */
    data class NoCanonicalClock(val identifiers: List<String>) : CountryZones

    val candidateIdentifiers: List<String>
        get() = when (this) {
            is Canonical -> listOf(identifier)
            is NoCanonicalClock -> identifiers
        }
}

/**
 * Country (and common-form) names → zones, verbatim from Swift
 * `CountryZoneTable`. Portugal is `Europe/Lisbon`, not the Azores; the six
 * countries the spec names (USA, Canada, Australia, Brazil, Russia, Mexico)
 * and one continent, Antarctica (item 25), prompt instead.
 */
object CountryZoneTable {
    /** The six primary US zones; Arizona deliberately absent. */
    private val unitedStatesZones = listOf(
        "America/New_York", "America/Chicago", "America/Denver",
        "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu",
    )

    /**
     * One research station per distinct clock (spec amendment 2026-10-28),
     * McMurdo first, then east to west. South Pole, Vostok and Palmer share a
     * listed clock; Dumont d'Urville is left out for its label.
     */
    private val antarcticStationZones = listOf(
        "Antarctica/McMurdo", "Antarctica/Macquarie", "Antarctica/Casey",
        "Antarctica/Davis", "Antarctica/Mawson", "Antarctica/Syowa",
        "Antarctica/Troll", "Antarctica/Rothera",
    )

    private val brazilZones = listOf(
        "America/Sao_Paulo", "America/Manaus",
        "America/Rio_Branco", "America/Noronha",
    )

    private fun canonical(identifier: String) = CountryZones.Canonical(identifier)
    private fun noClock(identifiers: List<String>) = CountryZones.NoCanonicalClock(identifiers)
    private fun noClock(vararg identifiers: String) = CountryZones.NoCanonicalClock(identifiers.toList())

    val zonesByCountryName: Map<String, CountryZones> = linkedMapOf(
        // No national clock — these prompt

        "usa" to noClock(unitedStatesZones),
        "us" to noClock(unitedStatesZones),
        "u.s." to noClock(unitedStatesZones),
        "america" to noClock(unitedStatesZones),
        "united states" to noClock(unitedStatesZones),
        "united states of america" to noClock(unitedStatesZones),
        "canada" to noClock(
            "America/Toronto", "America/Winnipeg", "America/Edmonton",
            "America/Vancouver", "America/Halifax", "America/St_Johns",
        ),
        "australia" to noClock(
            "Australia/Sydney", "Australia/Brisbane", "Australia/Adelaide",
            "Australia/Darwin", "Australia/Perth", "Australia/Hobart",
        ),
        "brazil" to noClock(brazilZones),
        "brasil" to noClock(brazilZones),
        "russia" to noClock(
            "Europe/Moscow", "Europe/Kaliningrad", "Asia/Yekaterinburg",
            "Asia/Omsk", "Asia/Krasnoyarsk", "Asia/Irkutsk",
            "Asia/Yakutsk", "Asia/Vladivostok", "Asia/Magadan", "Asia/Kamchatka",
        ),
        "mexico" to noClock(
            "America/Mexico_City", "America/Cancun",
            "America/Chihuahua", "America/Tijuana",
        ),

        // Continent-as-country (item 25) — also prompts

        "antarctica" to noClock(antarcticStationZones),

        // Multi-zone, but with a dominant national clock

        "portugal" to canonical("Europe/Lisbon"),
        "spain" to canonical("Europe/Madrid"),
        "chile" to canonical("America/Santiago"),
        "indonesia" to canonical("Asia/Jakarta"),
        "new zealand" to canonical("Pacific/Auckland"),
        "argentina" to canonical("America/Argentina/Buenos_Aires"),

        // Europe

        "united kingdom" to canonical("Europe/London"),
        "britain" to canonical("Europe/London"),
        "great britain" to canonical("Europe/London"),
        "england" to canonical("Europe/London"),
        "scotland" to canonical("Europe/London"),
        "wales" to canonical("Europe/London"),
        "ireland" to canonical("Europe/Dublin"),
        "france" to canonical("Europe/Paris"),
        "germany" to canonical("Europe/Berlin"),
        "italy" to canonical("Europe/Rome"),
        "netherlands" to canonical("Europe/Amsterdam"),
        "holland" to canonical("Europe/Amsterdam"),
        "belgium" to canonical("Europe/Brussels"),
        "switzerland" to canonical("Europe/Zurich"),
        "austria" to canonical("Europe/Vienna"),
        "poland" to canonical("Europe/Warsaw"),
        "czechia" to canonical("Europe/Prague"),
        "czech republic" to canonical("Europe/Prague"),
        "sweden" to canonical("Europe/Stockholm"),
        "norway" to canonical("Europe/Oslo"),
        "denmark" to canonical("Europe/Copenhagen"),
        "finland" to canonical("Europe/Helsinki"),
        "greece" to canonical("Europe/Athens"),
        "hungary" to canonical("Europe/Budapest"),
        "romania" to canonical("Europe/Bucharest"),
        "ukraine" to canonical("Europe/Kyiv"),
        "turkey" to canonical("Europe/Istanbul"),
        "iceland" to canonical("Atlantic/Reykjavik"),

        // Asia and the Middle East

        "japan" to canonical("Asia/Tokyo"),
        "china" to canonical("Asia/Shanghai"),
        "india" to canonical("Asia/Kolkata"),
        "pakistan" to canonical("Asia/Karachi"),
        "bangladesh" to canonical("Asia/Dhaka"),
        "sri lanka" to canonical("Asia/Colombo"),
        "nepal" to canonical("Asia/Kathmandu"),
        "south korea" to canonical("Asia/Seoul"),
        "korea" to canonical("Asia/Seoul"),
        "taiwan" to canonical("Asia/Taipei"),
        "thailand" to canonical("Asia/Bangkok"),
        "vietnam" to canonical("Asia/Ho_Chi_Minh"),
        "malaysia" to canonical("Asia/Kuala_Lumpur"),
        "philippines" to canonical("Asia/Manila"),
        "singapore" to canonical("Asia/Singapore"),
        "israel" to canonical("Asia/Jerusalem"),
        "uae" to canonical("Asia/Dubai"),
        "united arab emirates" to canonical("Asia/Dubai"),
        "saudi arabia" to canonical("Asia/Riyadh"),
        "qatar" to canonical("Asia/Qatar"),

        // Africa

        "egypt" to canonical("Africa/Cairo"),
        "south africa" to canonical("Africa/Johannesburg"),
        "nigeria" to canonical("Africa/Lagos"),
        "kenya" to canonical("Africa/Nairobi"),
        "morocco" to canonical("Africa/Casablanca"),
        "ghana" to canonical("Africa/Accra"),
        "ethiopia" to canonical("Africa/Addis_Ababa"),

        // The Americas

        "colombia" to canonical("America/Bogota"),
        "peru" to canonical("America/Lima"),
        "venezuela" to canonical("America/Caracas"),
        "uruguay" to canonical("America/Montevideo"),
        "cuba" to canonical("America/Havana"),
        "jamaica" to canonical("America/Jamaica"),
    )
}
