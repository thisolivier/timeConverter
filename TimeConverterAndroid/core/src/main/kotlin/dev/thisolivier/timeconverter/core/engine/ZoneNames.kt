package dev.thisolivier.timeconverter.core.engine

import kotlinx.serialization.json.Json
import java.time.ZoneId

/**
 * The zone's own name for the sub-line under the big time (item 21): `Eastern Time`, `Japan Standard Time`.
 *
 * Read from `/zone-names.json`, the Swift core's iOS-origin snapshot that the build puts on the classpath —
 * NOT from `java.time`, whose names disagree with iOS (`London Time` for Europe/London). iOS is the origin;
 * this side conforms, so both platforms print the same name.
 */
object ZoneNames {
    /** `{ "<tz identifier>": "<generic name>" }`, decoded once. Empty if the resource is missing. */
    val namesByIdentifier: Map<String, String> by lazy {
        val text = ZoneNames::class.java.getResource("/zone-names.json")?.readText() ?: return@lazy emptyMap()
        Json.decodeFromString<Map<String, String>>(text)
    }

    fun genericName(zone: ZoneId): String {
        val name = namesByIdentifier[zone.id]
        // An identifier newer than the snapshot: the same readable fallback as the Swift side.
        if (name.isNullOrBlank()) return "${ZoneDisplayName.forIdentifier(zone.id)} Time"
        return name
    }

    /** `Brasilia Standard Time (São Paulo)` under a place header; `New York, Toronto` under an abbreviation header. */
    fun zoneDetailLine(reading: ZoneReading): String = when (reading.label) {
        is ZoneLabel.Place -> "${genericName(ZoneId.of(reading.timeZoneIdentifier))} (${reading.cityName})"
        is ZoneLabel.Abbreviation -> reading.representativeCities.joinToString(", ")
    }
}
