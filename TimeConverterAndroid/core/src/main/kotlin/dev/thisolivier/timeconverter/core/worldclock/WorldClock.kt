package dev.thisolivier.timeconverter.core.worldclock

import dev.thisolivier.timeconverter.core.engine.ConversionEngine
import dev.thisolivier.timeconverter.core.engine.ConversionResult
import dev.thisolivier.timeconverter.core.engine.ResolvedZone
import dev.thisolivier.timeconverter.core.engine.WallClockResolver
import dev.thisolivier.timeconverter.core.parsing.ParsedTime
import dev.thisolivier.timeconverter.core.presentation.ConverterPresenter
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * The world clock: the device's local clock shifted by an offset, read in
 * every favourite's zone. Port of Swift `WorldClock` (see its comments).
 *
 * - The offset shifts the local **wall clock**, not the instant (`+1 d` is the
 *   same local time tomorrow, across DST too); the shifted wall clock resolves
 *   through the converter's own `WallClockResolver` policy. At zero the real
 *   `now` is read straight through.
 * - Every row's day marker, the local row included, is measured against the
 *   **real local today**, the same reference as the readout's `Today`.
 *
 * Pure: `now` and `localZone` are injected.
 */
object WorldClock {
    fun readings(
        favourites: List<FavouriteDestination>,
        offsetMinutes: Int,
        now: Instant,
        localZone: ZoneId,
    ): WorldClockDisplay {
        val shifted = ShiftedLocalClock.resolve(offsetMinutes, now, localZone)
        val localZoneResolved = ResolvedZone.deviceLocal(localZone)

        fun result(targetZone: ResolvedZone): ConversionResult = ConversionEngine.read(
            shifted.instant,
            from = localZoneResolved,
            to = targetZone,
            requestedTime = shifted.requestedTime,
            wallClockDisposition = shifted.disposition,
        )

        val today = ConversionEngine.dayNumber(now, localZone)
        val localResult = result(localZoneResolved)
        val localRow = row(localResult, favourite = null, today = today)
        val favouriteRows = favourites.mapNotNull { favourite ->
            favourite.resolvedZone?.let { zone -> row(result(zone), favourite, today) }
        }

        return WorldClockDisplay(
            readout = WorldClockFormatting.readout(
                dayDifference = ConversionEngine.dayNumber(shifted.instant, localZone) - today,
                shiftedInstant = shifted.instant,
                localZone = localZone,
                uppercasedTime = localResult.target.uppercasedTime,
            ),
            offsetDescription = WorldClockFormatting.offsetDescription(offsetMinutes),
            rows = listOf(localRow) + favouriteRows,
        )
    }

    private fun row(result: ConversionResult, favourite: FavouriteDestination?, today: Int): WorldClockRow {
        val rowZone = ZoneId.of(result.target.timeZoneIdentifier)
        return WorldClockRow(
            id = favourite?.id ?: "local",
            placeName = result.target.placeNameDescription,
            clockDigits = result.target.clockDigits,
            meridiem = result.target.uppercasedMeridiem,
            // The converter's own zone detail, with the day marker against the real local today.
            zoneLine = ConverterPresenter.zoneLine(
                zoneDetail = ConverterPresenter.zoneDetail(result.target),
                dayOffset = ConversionEngine.dayNumber(result.instant, rowZone) - today,
            ),
            offsetPhrase = if (favourite == null) "" else result.relativeOffsetPhrase,
            favourite = favourite,
        )
    }
}

/** The local wall clock moved by whole minutes, resolved back to an instant. Port of Swift `ShiftedLocalClock`. */
object ShiftedLocalClock {
    data class Outcome(
        val instant: Instant,
        val requestedTime: ParsedTime,
        val disposition: WallClockResolver.Disposition,
    )

    fun resolve(offsetMinutes: Int, now: Instant, localZone: ZoneId): Outcome {
        if (offsetMinutes == 0) {
            return Outcome(now, ParsedTime.wallClock(now, localZone), WallClockResolver.Disposition.Unambiguous)
        }
        // The wall clock as a naive date-time, shifted by plain arithmetic — no
        // zone, so no DST, until the resolver below. Seconds dropped, as Swift does.
        val shiftedWallClock = LocalDateTime.ofInstant(now, localZone)
            .truncatedTo(ChronoUnit.MINUTES)
            .plusMinutes(offsetMinutes.toLong())
        val requestedTime = ParsedTime(shiftedWallClock.hour, shiftedWallClock.minute)
        val resolved = WallClockResolver.resolve(requestedTime, onCalendarDay = shiftedWallClock.toLocalDate(), zone = localZone)
        return Outcome(resolved.instant, requestedTime, resolved.disposition)
    }
}
