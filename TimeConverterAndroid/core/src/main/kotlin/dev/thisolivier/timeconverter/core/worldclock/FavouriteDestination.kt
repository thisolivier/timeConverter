package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.ZoneLabel
import dev.thisolivier.timeconverter.core.engine.ZoneReading
import dev.thisolivier.timeconverter.core.parsing.InputParser
import dev.thisolivier.timeconverter.core.parsing.ZoneMatchSource
import dev.thisolivier.timeconverter.core.parsing.ZoneResolution
import dev.thisolivier.timeconverter.core.parsing.ZoneResolverChain
import java.time.DateTimeException
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * A starred destination (item 30/32): the zone the converter resolved, plus
 * the label the user asked for it with. Port of Swift `FavouriteDestination`.
 *
 * The label is part of the identity on purpose: starring `New York` and
 * starring `ET` are two favourites on one zone.
 */
data class FavouriteDestination(val timeZoneIdentifier: String, val label: ZoneLabel) {
    /**
     * Stable across launches and unique per (identifier, label) pair, the same
     * string Swift derives: `Europe/London|place:London`,
     * `America/New_York|code:ET:Eastern Time`.
     */
    val id: String
        get() = when (label) {
            is ZoneLabel.Place -> "$timeZoneIdentifier|place:${label.name}${if (label.isDeviceLocal) ":local" else ""}"
            is ZoneLabel.Abbreviation -> "$timeZoneIdentifier|code:${label.code}:${label.expandedName}"
        }

    /**
     * The zone as the converter would have resolved it, so the world clock runs
     * the very same engine path; null for an identifier this runtime does not
     * know (the clock skips it). A code label recovers its curated cities by
     * asking the resolver chain again (`ET` → New York, Toronto).
     */
    val resolvedZone: ResolvedZone?
        get() {
            val zone = try {
                ZoneId.of(timeZoneIdentifier)
            } catch (_: DateTimeException) {
                return null
            }
            return when (label) {
                is ZoneLabel.Place -> ResolvedZone(
                    zone = zone,
                    displayName = label.name,
                    label = ZoneLabel.Place(label.name, isDeviceLocal = false),
                    matchSource = ZoneMatchSource.TimeZoneDatabaseCity,
                    originalToken = label.name.lowercase(),
                )
                is ZoneLabel.Abbreviation -> ResolvedZone(
                    zone = zone,
                    displayName = label.expandedName,
                    representativeCities = curatedCities(label.code, timeZoneIdentifier),
                    label = label,
                    matchSource = ZoneMatchSource.AliasTable,
                    originalToken = label.code.lowercase(),
                )
            }
        }

    companion object {
        /**
         * The favourite a conversion's target would make, or null for a target
         * defaulted to the device zone: the local clock is always the world
         * clock's first row, so `(local)` cannot be starred.
         */
        fun fromConverterTarget(target: ZoneReading): FavouriteDestination? =
            if (target.isDeviceLocalZone) null else FavouriteDestination(target.timeZoneIdentifier, target.label)

        /**
         * What starring the target of `12pm in <typedZone>` would store, or null
         * when that sentence does not convert. Used by the DEBUG `favourites`
         * seed so it stores exactly what a real tap on the star would.
         */
        fun resolvingTypedZone(typedZone: String): FavouriteDestination? {
            val anyFixedInstant = Instant.ofEpochSecond(1_768_478_400)
            val outcome = InputParser().parseAndConvert("12pm in $typedZone", anyFixedInstant, ZoneOffset.UTC)
            return (outcome as? InputParser.Outcome.Converted)?.let { fromConverterTarget(it.result.target) }
        }

        private fun curatedCities(code: String, identifier: String): List<String> =
            when (val resolution = ZoneResolverChain.standard.resolve(code.lowercase())) {
                is ZoneResolution.Resolved ->
                    if (resolution.zone.zone.id == identifier) resolution.zone.representativeCities else emptyList()
                is ZoneResolution.Ambiguous -> resolution.candidates
                    .firstOrNull { it.timeZoneIdentifier == identifier }
                    ?.abbreviationDisplay?.representativeCities.orEmpty()
                ZoneResolution.Unknown -> emptyList()
            }
    }
}
