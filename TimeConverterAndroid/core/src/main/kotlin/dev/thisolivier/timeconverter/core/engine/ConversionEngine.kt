package dev.thisolivier.timeconverter.core.engine

import dev.thisolivier.timeconverter.core.parsing.ParsedTime
import java.time.Instant

/** How one zone reads the converted instant. Port of Swift `ZoneReading`. */
data class ZoneReading(
    val timeZoneIdentifier: String,
    val zoneDisplayName: String,
    val representativeCities: List<String>,
    val label: ZoneLabel,
    /** Canonical 12-hour form, `5:00 pm`. */
    val formattedTime: String,
    val utcOffsetDescription: String,
    val utcOffsetSeconds: Int,
    val isDeviceLocalZone: Boolean,
) {
    val cityName: String get() = ZoneDisplayName.forIdentifier(timeZoneIdentifier)

    /** `5:00 pm London (UTC+0)`, `12:00 pm Eastern Time (New York, Toronto, UTC-5)`, `… (local, UTC-8)`. */
    val echoDescription: String
        get() {
            val localMarker = if (isDeviceLocalZone) listOf("local") else emptyList()
            val parenthetical = (localMarker + representativeCities + utcOffsetDescription).joinToString(", ")
            return "$formattedTime $zoneDisplayName ($parenthetical)"
        }

    /** `Lisbon`, `Eastern Time (New York, Toronto)`, `Los Angeles (local)`. */
    val placeDescription: String
        get() {
            val localMarker = if (isDeviceLocalZone) listOf("local") else emptyList()
            val qualifiers = localMarker + representativeCities
            if (qualifiers.isEmpty()) return zoneDisplayName
            return "$zoneDisplayName (${qualifiers.joinToString(", ")})"
        }

    val headerDescription: String get() = label.headerDescription
    val placeNameDescription: String get() = label.placeNameDescription
    val uppercasedTime: String get() = formattedTime.uppercase()
    /** `4:00` from `4:00 pm`. */
    val clockDigits: String get() = formattedTime.substringBefore(' ')
    /** `PM` from `4:00 pm`. */
    val uppercasedMeridiem: String get() = formattedTime.substringAfter(' ').uppercase()
}

/** Display-ready output. Port of Swift `ConversionResult`. */
data class ConversionResult(
    val instant: Instant,
    val source: ZoneReading,
    val target: ZoneReading,
    /** Target calendar day minus source calendar day. */
    val dayOffset: Int,
    val wallClockDisposition: WallClockResolver.Disposition,
    val requestedTime: ParsedTime,
) {
    val dayRolloverMarker: String?
        get() = when {
            dayOffset == 0 -> null
            dayOffset > 0 -> "+${dayOffset}d"
            else -> "${dayOffset}d"
        }

    /** `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0) +1d`. */
    val summary: String
        get() {
            val line = "${source.echoDescription} → ${target.echoDescription}"
            return dayRolloverMarker?.let { "$line $it" } ?: line
        }

    val dayRolloverNote: String?
        get() = when (dayOffset) {
            0 -> null
            1 -> "next day"
            -1 -> "previous day"
            else -> if (dayOffset > 0) "+$dayOffset days" else "$dayOffset days"
        }

    private val relativeOffsetSeconds: Int get() = target.utcOffsetSeconds - source.utcOffsetSeconds

    val relativeOffsetSentence: String
        get() = RelativeOffsetFormatting.sentence(relativeOffsetSeconds, target.zoneDisplayName, source.zoneDisplayName)

    val relativeOffsetPhrase: String get() = RelativeOffsetFormatting.phrase(relativeOffsetSeconds)
}

data class ConversionRequest(
    val time: ParsedTime,
    val sourceZone: ResolvedZone,
    val targetZone: ResolvedZone,
    /** Supplies "today"; the engine never reads the clock. */
    val referenceInstant: Instant,
)

/** Runs a resolved request. Pure. Port of Swift `ConversionEngine`. */
object ConversionEngine {
    fun convert(request: ConversionRequest): ConversionResult {
        val wallClockOutcome = WallClockResolver.resolve(request.time, request.referenceInstant, request.sourceZone.zone)
        val instant = wallClockOutcome.instant
        return ConversionResult(
            instant = instant,
            source = reading(instant, request.sourceZone),
            target = reading(instant, request.targetZone),
            dayOffset = (instant.atZone(request.targetZone.zone).toLocalDate().toEpochDay()
                - instant.atZone(request.sourceZone.zone).toLocalDate().toEpochDay()).toInt(),
            wallClockDisposition = wallClockOutcome.disposition,
            requestedTime = request.time,
        )
    }

    private fun reading(instant: Instant, zone: ResolvedZone): ZoneReading {
        val local = instant.atZone(zone.zone)
        return ZoneReading(
            timeZoneIdentifier = zone.zone.id,
            zoneDisplayName = zone.displayName,
            representativeCities = zone.representativeCities,
            label = zone.label,
            formattedTime = TimeFormatting.twelveHourDescription(local.hour, local.minute),
            utcOffsetDescription = UtcOffsetFormatting.description(zone.zone, instant),
            utcOffsetSeconds = local.offset.totalSeconds,
            isDeviceLocalZone = zone.isDeviceLocalZone,
        )
    }
}
