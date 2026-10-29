import Foundation

/// The world clock (item 30): the device's local clock shifted by an offset,
/// read in every favourite's zone.
///
/// ## What the offset means
///
/// It shifts the local **wall clock**, not the instant: `+1 d` is the same
/// local time tomorrow even across a daylight-saving change, which is what the
/// slider is for. Each row is then exactly a conversion from local at the
/// shifted wall-clock time to that favourite, so the DST policy is the
/// converter's own: a shifted time that falls in a spring-forward gap moves to
/// the next valid instant, and a repeated one takes the earlier.
///
/// At zero the clock is simply live — the real `now` is read straight through,
/// with no wall-clock round trip that could pick the wrong half of a repeated
/// hour.
///
/// ## What the day marker means
///
/// Every row's `· next day` / `· previous day` is measured against the **real
/// local today**, the local row included, so it agrees with the readout's
/// `Tomorrow`. Build 20 measured it against the shifted local row instead,
/// which read backwards under the dial: push London to 1 AM tomorrow and Los
/// Angeles, still on today, said "previous day"; push on to 9 AM and the
/// marker vanished just as Los Angeles crossed into tomorrow (Olivier,
/// 2026-10-29: "progressing linearly in time shouldn't jump in and out of
/// yesterday").
///
/// Pure: `now` and `localZone` are injected, as everywhere in this package.
public enum WorldClock {
    public static func readings(
        favourites: [FavouriteDestination],
        offset: TimeInterval,
        now: Date,
        localZone: TimeZone
    ) -> WorldClockDisplay {
        let offsetMinutes = Int((offset / 60).rounded())
        let shifted = ShiftedLocalClock.resolve(offsetMinutes: offsetMinutes, now: now, localZone: localZone)
        let localZoneResolved = ResolvedZone.deviceLocal(localZone)
        let engine = ConversionEngine()

        func result(for targetZone: ResolvedZone) -> ConversionResult {
            engine.read(
                shifted.instant,
                from: localZoneResolved,
                to: targetZone,
                requestedTime: shifted.requestedTime,
                wallClockDisposition: shifted.disposition
            )
        }

        let today = ConversionEngine.dayNumber(of: now, in: localZone)
        let localResult = result(for: localZoneResolved)
        let localRow = row(for: localResult, favourite: nil, today: today)
        let favouriteRows = favourites.compactMap { favourite -> WorldClockRow? in
            guard let zone = favourite.resolvedZone else { return nil }
            return row(for: result(for: zone), favourite: favourite, today: today)
        }

        return WorldClockDisplay(
            readout: WorldClockFormatting.readout(
                dayDifference: ConversionEngine.dayNumber(of: shifted.instant, in: localZone) - today,
                shiftedInstant: shifted.instant,
                localZone: localZone,
                uppercasedTime: localResult.target.uppercasedTime
            ),
            offsetDescription: WorldClockFormatting.offsetDescription(minutes: offsetMinutes),
            rows: [localRow] + favouriteRows
        )
    }

    private static func row(
        for result: ConversionResult, favourite: FavouriteDestination?, today: Int
    ) -> WorldClockRow {
        let rowZone = TimeZone(identifier: result.target.timeZoneIdentifier) ?? .current
        return WorldClockRow(
            id: favourite?.id ?? "local",
            placeName: result.target.placeNameDescription,
            clockDigits: result.target.clockDigits,
            meridiem: result.target.uppercasedMeridiem,
            // The converter's own zone detail, with the day marker measured
            // against the real local today (see the type comment).
            zoneLine: ConverterPresenter.zoneLine(
                zoneDetail: result.target.zoneDetailDescription,
                dayOffset: ConversionEngine.dayNumber(of: result.instant, in: rowZone) - today
            ),
            offsetPhrase: favourite == nil ? "" : result.relativeOffsetPhrase,
            favourite: favourite
        )
    }
}

/// The local wall clock moved by whole minutes, resolved back to an instant.
enum ShiftedLocalClock {
    struct Outcome: Equatable, Sendable {
        let instant: Date
        let requestedTime: ParsedTime
        let disposition: WallClockResolver.Disposition
    }

    static func resolve(offsetMinutes: Int, now: Date, localZone: TimeZone) -> Outcome {
        guard offsetMinutes != 0 else {
            return Outcome(
                instant: now,
                requestedTime: ParsedTime.wallClock(of: now, in: localZone),
                disposition: .unambiguous
            )
        }
        // The wall clock as a naive date-time (read as if UTC), shifted by
        // plain arithmetic — no zone, so no DST, until the resolver below.
        let wallClock = GregorianCalendars.calendar(in: localZone)
            .dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let naiveNow = GregorianCalendars.utc.date(from: wallClock) ?? now
        let naiveShifted = naiveNow.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        let shiftedComponents = GregorianCalendars.utc
            .dateComponents([.year, .month, .day, .hour, .minute], from: naiveShifted)
        let requestedTime = ParsedTime(
            hour: shiftedComponents.hour ?? 0, minute: shiftedComponents.minute ?? 0
        )
        let resolved = WallClockResolver.resolve(
            wallClock: requestedTime,
            onCalendarDay: DateComponents(
                year: shiftedComponents.year, month: shiftedComponents.month, day: shiftedComponents.day
            ),
            in: localZone
        )
        return Outcome(
            instant: resolved.instant, requestedTime: requestedTime, disposition: resolved.disposition
        )
    }
}
