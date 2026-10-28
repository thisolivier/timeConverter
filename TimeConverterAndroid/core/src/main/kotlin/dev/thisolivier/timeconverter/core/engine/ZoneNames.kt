package dev.thisolivier.timeconverter.core.engine

import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

/** The zone's own name for the sub-line under the big time (item 21): `Eastern Time`, `Japan Standard Time`. */
object ZoneNames {
    /** Pinned to en_US like the Swift side — every other label in the app is hand-written English. */
    private val locale: Locale = Locale.US

    fun genericName(zone: ZoneId): String {
        val name = zone.getDisplayName(TextStyle.FULL, locale)
        // java.time answers the identifier itself for zones it has no name for.
        if (name.isBlank() || name == zone.id) return "${ZoneDisplayName.forIdentifier(zone.id)} Time"
        return name
    }

    /** `Brasilia Standard Time (São Paulo)` under a place header; `New York, Toronto` under an abbreviation header. */
    fun zoneDetailLine(reading: ZoneReading): String = when (reading.label) {
        is ZoneLabel.Place -> "${genericName(ZoneId.of(reading.timeZoneIdentifier))} (${reading.cityName})"
        is ZoneLabel.Abbreviation -> reading.representativeCities.joinToString(", ")
    }
}
