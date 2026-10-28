import Foundation

/// What a country name resolves to.
///
/// The distinction is the spec's amended country policy: most countries have a
/// *national clock* even when the tz database splits them into several zones,
/// and prompting for those is noise. Only countries where no single clock can
/// claim to be "the" national time offer a picker.
enum CountryZones: Equatable, Sendable {
    /// A dominant national clock: the time a clock on the country's mainland
    /// street shows. One candidate, so the token resolves directly. DST comes
    /// free because the value is an IANA zone, not a fixed offset.
    case canonical(String)

    /// No single national clock — every zone is offered and the user picks.
    case noCanonicalClock([String])

    /// What the resolver emits for this entry.
    var candidateIdentifiers: [String] {
        switch self {
        case let .canonical(identifier): return [identifier]
        case let .noCanonicalClock(identifiers): return identifiers
        }
    }
}

/// Country (and common-form) names mapped to their zones.
///
/// Canonical-zone rule: the zone a clock on the country's mainland street
/// shows. Portugal is `Europe/Lisbon`, not `Atlantic/Azores`; Spain is
/// `Europe/Madrid`, not `Atlantic/Canary`. Only the six countries the spec
/// names — USA, Canada, Australia, Brazil, Russia, Mexico — have no such clock
/// and prompt instead, plus one continent: Antarctica (item 25). Their
/// candidate lists are ordered most-populous-first, because the chain shows
/// candidates in table order.
///
/// This is a curated seed, not a gazetteer: it covers the countries people
/// actually type. Unlisted countries fall through to step 5.
enum CountryZoneTable {
    static let zonesByCountryName: [String: CountryZones] = [
        // MARK: No national clock — these prompt

        "usa": .noCanonicalClock(unitedStatesZones),
        "us": .noCanonicalClock(unitedStatesZones),
        "u.s.": .noCanonicalClock(unitedStatesZones),
        "america": .noCanonicalClock(unitedStatesZones),
        "united states": .noCanonicalClock(unitedStatesZones),
        "united states of america": .noCanonicalClock(unitedStatesZones),
        "canada": .noCanonicalClock([
            "America/Toronto", "America/Winnipeg", "America/Edmonton",
            "America/Vancouver", "America/Halifax", "America/St_Johns",
        ]),
        "australia": .noCanonicalClock([
            "Australia/Sydney", "Australia/Brisbane", "Australia/Adelaide",
            "Australia/Darwin", "Australia/Perth", "Australia/Hobart",
        ]),
        "brazil": .noCanonicalClock(brazilZones),
        "brasil": .noCanonicalClock(brazilZones),
        "russia": .noCanonicalClock([
            "Europe/Moscow", "Europe/Kaliningrad", "Asia/Yekaterinburg",
            "Asia/Omsk", "Asia/Krasnoyarsk", "Asia/Irkutsk",
            "Asia/Yakutsk", "Asia/Vladivostok", "Asia/Magadan", "Asia/Kamchatka",
        ]),
        "mexico": .noCanonicalClock([
            "America/Mexico_City", "America/Cancun",
            "America/Chihuahua", "America/Tijuana",
        ]),

        // MARK: Continent-as-country (item 25) — also prompts

        "antarctica": .noCanonicalClock(antarcticStationZones),

        // MARK: Multi-zone, but with a dominant national clock

        "portugal": .canonical("Europe/Lisbon"),
        "spain": .canonical("Europe/Madrid"),
        "chile": .canonical("America/Santiago"),
        "indonesia": .canonical("Asia/Jakarta"),
        "new zealand": .canonical("Pacific/Auckland"),
        "argentina": .canonical("America/Argentina/Buenos_Aires"),

        // MARK: Europe

        "united kingdom": .canonical("Europe/London"),
        "britain": .canonical("Europe/London"),
        "great britain": .canonical("Europe/London"),
        "england": .canonical("Europe/London"),
        "scotland": .canonical("Europe/London"),
        "wales": .canonical("Europe/London"),
        "ireland": .canonical("Europe/Dublin"),
        "france": .canonical("Europe/Paris"),
        "germany": .canonical("Europe/Berlin"),
        "italy": .canonical("Europe/Rome"),
        "netherlands": .canonical("Europe/Amsterdam"),
        "holland": .canonical("Europe/Amsterdam"),
        "belgium": .canonical("Europe/Brussels"),
        "switzerland": .canonical("Europe/Zurich"),
        "austria": .canonical("Europe/Vienna"),
        "poland": .canonical("Europe/Warsaw"),
        "czechia": .canonical("Europe/Prague"),
        "czech republic": .canonical("Europe/Prague"),
        "sweden": .canonical("Europe/Stockholm"),
        "norway": .canonical("Europe/Oslo"),
        "denmark": .canonical("Europe/Copenhagen"),
        "finland": .canonical("Europe/Helsinki"),
        "greece": .canonical("Europe/Athens"),
        "hungary": .canonical("Europe/Budapest"),
        "romania": .canonical("Europe/Bucharest"),
        "ukraine": .canonical("Europe/Kyiv"),
        "turkey": .canonical("Europe/Istanbul"),
        "iceland": .canonical("Atlantic/Reykjavik"),

        // MARK: Asia and the Middle East

        "japan": .canonical("Asia/Tokyo"),
        "china": .canonical("Asia/Shanghai"),
        "india": .canonical("Asia/Kolkata"),
        "pakistan": .canonical("Asia/Karachi"),
        "bangladesh": .canonical("Asia/Dhaka"),
        "sri lanka": .canonical("Asia/Colombo"),
        "nepal": .canonical("Asia/Kathmandu"),
        "south korea": .canonical("Asia/Seoul"),
        "korea": .canonical("Asia/Seoul"),
        "taiwan": .canonical("Asia/Taipei"),
        "thailand": .canonical("Asia/Bangkok"),
        "vietnam": .canonical("Asia/Ho_Chi_Minh"),
        "malaysia": .canonical("Asia/Kuala_Lumpur"),
        "philippines": .canonical("Asia/Manila"),
        "singapore": .canonical("Asia/Singapore"),
        "israel": .canonical("Asia/Jerusalem"),
        "uae": .canonical("Asia/Dubai"),
        "united arab emirates": .canonical("Asia/Dubai"),
        "saudi arabia": .canonical("Asia/Riyadh"),
        "qatar": .canonical("Asia/Qatar"),

        // MARK: Africa

        "egypt": .canonical("Africa/Cairo"),
        "south africa": .canonical("Africa/Johannesburg"),
        "nigeria": .canonical("Africa/Lagos"),
        "kenya": .canonical("Africa/Nairobi"),
        "morocco": .canonical("Africa/Casablanca"),
        "ghana": .canonical("Africa/Accra"),
        "ethiopia": .canonical("Africa/Addis_Ababa"),

        // MARK: The Americas

        "colombia": .canonical("America/Bogota"),
        "peru": .canonical("America/Lima"),
        "venezuela": .canonical("America/Caracas"),
        "uruguay": .canonical("America/Montevideo"),
        "cuba": .canonical("America/Havana"),
        "jamaica": .canonical("America/Jamaica"),
    ]

    /// The six primary US zones, per the spec. Arizona is deliberately absent:
    /// it shares Mountain wall-clock time for part of the year and listing it
    /// would add a seventh, confusing row to the picker.
    private static let unitedStatesZones = [
        "America/New_York", "America/Chicago", "America/Denver",
        "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu",
    ]

    /// One research station per distinct clock (spec amendment 2026-10-28):
    /// McMurdo first as the largest station, then east to west. Left out
    /// because another row already shows their clock: South Pole (a link to
    /// McMurdo), Vostok (Mawson's +5), Palmer (Rothera's −3). Left out for its
    /// label: Dumont d'Urville, whose identifier city renders `DumontDUrville`.
    /// Every station still resolves by name through step 3.
    private static let antarcticStationZones = [
        "Antarctica/McMurdo", "Antarctica/Macquarie", "Antarctica/Casey",
        "Antarctica/Davis", "Antarctica/Mawson", "Antarctica/Syowa",
        "Antarctica/Troll", "Antarctica/Rothera",
    ]

    private static let brazilZones = [
        "America/Sao_Paulo", "America/Manaus",
        "America/Rio_Branco", "America/Noronha",
    ]
}
