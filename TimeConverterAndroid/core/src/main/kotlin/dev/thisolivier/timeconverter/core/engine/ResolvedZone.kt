package dev.thisolivier.timeconverter.core.engine

import java.time.ZoneId

/**
 * How the result band names a zone — port of Swift `ZoneLabel` (item 21).
 * A function of *how the token resolved*, not of the zone.
 */
sealed interface ZoneLabel {
    data class Place(val name: String, val isDeviceLocal: Boolean) : ZoneLabel
    data class Abbreviation(val code: String, val expandedName: String) : ZoneLabel

    /** `São Paulo`, `ET (Eastern Time)`, `Los Angeles (local)`. */
    val placeNameDescription: String
        get() = when (this) {
            is Place -> if (isDeviceLocal) "$name (local)" else name
            is Abbreviation -> "$code ($expandedName)"
        }

    val headerDescription: String get() = "In $placeNameDescription"
}

/**
 * A zone the parser has settled on — the engine's input. Port of the slice of
 * Swift `ResolvedZone` the engine reads.
 */
data class ResolvedZone(
    val zone: ZoneId,
    /** The echo's name: a city for place tokens, the expanded name for abbreviations. */
    val displayName: String,
    /** Cities shown beside an expanded abbreviation; empty otherwise. */
    val representativeCities: List<String> = emptyList(),
    val label: ZoneLabel = ZoneLabel.Place(displayName, isDeviceLocal = false),
    val isDeviceLocalZone: Boolean = false,
) {
    companion object {
        /** The plainest resolution: an identifier read as a place. */
        fun place(identifier: String, isDeviceLocal: Boolean = false): ResolvedZone {
            val name = ZoneDisplayName.forIdentifier(identifier)
            return ResolvedZone(
                zone = ZoneId.of(identifier),
                displayName = name,
                label = ZoneLabel.Place(name, isDeviceLocal),
                isDeviceLocalZone = isDeviceLocal,
            )
        }
    }
}
