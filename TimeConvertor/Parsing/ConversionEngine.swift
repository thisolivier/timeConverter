import Foundation

/// How one zone reads the converted instant.
struct ZoneReading: Equatable, Sendable {
    let timeZoneIdentifier: String
    let zoneDisplayName: String
    /// Canonical 12-hour form, e.g. `5:00 pm`.
    let formattedTime: String
    /// e.g. `UTC+0`, `UTC-5`, `UTC+5:30`.
    let utcOffsetDescription: String
}

/// Display-ready output: everything item 4 needs to render the echo line, with
/// no further date maths.
struct ConversionResult: Equatable, Sendable {
    /// The single instant both readings describe.
    let instant: Date
    let source: ZoneReading
    let target: ZoneReading
    /// Target calendar day minus source calendar day. 0 for same day.
    let dayOffset: Int
    /// What the DST policy had to do, if anything.
    let wallClockDisposition: WallClockResolver.Disposition
    /// The time as typed, before the DST policy possibly moved it.
    let requestedTime: ParsedTime

    /// `+1d` / `-1d` when the date rolls over, nil when it doesn't.
    var dayRolloverMarker: String? {
        guard dayOffset != 0 else { return nil }
        return dayOffset > 0 ? "+\(dayOffset)d" : "\(dayOffset)d"
    }

    /// The spec's echo line:
    /// `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0)`, with the rollover
    /// marker appended when there is one.
    var summary: String {
        let line = "\(source.formattedTime) \(source.zoneDisplayName) "
            + "(\(source.utcOffsetDescription)) → "
            + "\(target.formattedTime) \(target.zoneDisplayName) "
            + "(\(target.utcOffsetDescription))"
        guard let dayRolloverMarker else { return line }
        return "\(line) \(dayRolloverMarker)"
    }
}

/// Runs a resolved `ConversionRequest`. Pure: the reference date travels on the
/// request, so the engine never reads the clock.
struct ConversionEngine: Sendable {
    func convert(_ request: ConversionRequest) -> ConversionResult {
        let wallClockOutcome = WallClockResolver.resolve(
            wallClock: request.time,
            onDayOf: request.referenceDate,
            in: request.sourceZone.timeZone
        )
        let instant = wallClockOutcome.instant

        let sourceReading = reading(of: instant, in: request.sourceZone)
        let targetReading = reading(of: instant, in: request.targetZone)

        return ConversionResult(
            instant: instant,
            source: sourceReading,
            target: targetReading,
            dayOffset: dayNumber(of: instant, in: request.targetZone.timeZone)
                - dayNumber(of: instant, in: request.sourceZone.timeZone),
            wallClockDisposition: wallClockOutcome.disposition,
            requestedTime: request.time
        )
    }

    // MARK: - Helpers

    /// Reads the instant through one zone. Note the source reading is derived
    /// from the resolved instant, not from the requested time: on a
    /// spring-forward gap that is how the shift becomes visible to the user.
    private func reading(of instant: Date, in zone: ResolvedZone) -> ZoneReading {
        let components = GregorianCalendars.calendar(in: zone.timeZone)
            .dateComponents([.hour, .minute], from: instant)
        return ZoneReading(
            timeZoneIdentifier: zone.timeZone.identifier,
            zoneDisplayName: zone.displayName,
            formattedTime: TimeFormatting.twelveHourDescription(
                hour: components.hour ?? 0,
                minute: components.minute ?? 0
            ),
            utcOffsetDescription: UTCOffsetFormatting.description(for: zone.timeZone, at: instant)
        )
    }

    /// Days since the Unix epoch for the calendar date the instant falls on in
    /// a given zone. Reducing both zones to a plain day count is what makes the
    /// rollover comparison trivial and month/year-boundary safe.
    private func dayNumber(of instant: Date, in timeZone: TimeZone) -> Int {
        let localDay = GregorianCalendars.calendar(in: timeZone)
            .dateComponents([.year, .month, .day], from: instant)
        guard let dayStartInUTC = GregorianCalendars.utc.date(from: DateComponents(
            year: localDay.year,
            month: localDay.month,
            day: localDay.day
        )) else { return 0 }
        return Int((dayStartInUTC.timeIntervalSince1970 / 86_400).rounded(.down))
    }
}
