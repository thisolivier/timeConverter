import Foundation

/// How one zone reads the converted instant.
struct ZoneReading: Equatable, Sendable {
    let timeZoneIdentifier: String
    /// The name the echo uses: a city for city/country tokens, the expanded
    /// zone name for abbreviations (`Eastern Time`).
    let zoneDisplayName: String
    /// Cities shown beside an expanded abbreviation name; empty otherwise.
    let representativeCities: [String]
    /// Canonical 12-hour form, e.g. `5:00 pm`.
    let formattedTime: String
    /// e.g. `UTC+0`, `UTC-5`, `UTC+5:30`.
    let utcOffsetDescription: String
    /// The same offset as a raw number, kept because the footer sentence is
    /// arithmetic on two offsets and parsing it back out of `UTC+5:30` would be
    /// absurd.
    let utcOffsetSeconds: Int
    /// True when the user never named this side and it was filled in from the
    /// device zone, which the echo marks as `(local, …)`.
    let isDeviceLocalZone: Bool

    init(
        timeZoneIdentifier: String,
        zoneDisplayName: String,
        representativeCities: [String] = [],
        formattedTime: String,
        utcOffsetDescription: String,
        utcOffsetSeconds: Int,
        isDeviceLocalZone: Bool = false
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.zoneDisplayName = zoneDisplayName
        self.representativeCities = representativeCities
        self.formattedTime = formattedTime
        self.utcOffsetDescription = utcOffsetDescription
        self.utcOffsetSeconds = utcOffsetSeconds
        self.isDeviceLocalZone = isDeviceLocalZone
    }

    /// The plain city for this zone, regardless of how the token was written.
    /// Prose that names a place ("doesn't exist today in New York") wants this,
    /// not the expanded zone name.
    var cityName: String {
        ZoneDisplayName.forIdentifier(timeZoneIdentifier)
    }

    /// One side of the echo line.
    ///
    /// `5:00 pm London (UTC+0)` for a place, and for an abbreviation the cities
    /// join the *same* parenthetical as the offset —
    /// `12:00 pm Eastern Time (New York, Toronto, UTC-5)` — rather than opening
    /// a second one. The offset's own rendering is untouched.
    ///
    /// A side defaulted to the device zone leads that same parenthetical with
    /// `local` — `7:00 pm Los Angeles (local, UTC-8)` — which is how the
    /// assumption becomes visible instead of silent.
    var echoDescription: String {
        let localMarker = isDeviceLocalZone ? ["local"] : []
        let parenthetical = (localMarker + representativeCities + [utcOffsetDescription])
            .joined(separator: ", ")
        return "\(formattedTime) \(zoneDisplayName) (\(parenthetical))"
    }

    /// The place on its own, with whatever qualifies it: `Lisbon`,
    /// `Eastern Time (New York, Toronto)`, `Los Angeles (local)`.
    ///
    /// Same vocabulary as `echoDescription` minus the time and the offset,
    /// because the redesigned iOS layout (item 18) puts those in their own
    /// slots instead of running them into one sentence.
    var placeDescription: String {
        let localMarker = isDeviceLocalZone ? ["local"] : []
        let qualifiers = localMarker + representativeCities
        guard !qualifiers.isEmpty else { return zoneDisplayName }
        return "\(zoneDisplayName) (\(qualifiers.joined(separator: ", ")))"
    }

    /// The shortest honest name for this zone: the display name, plus the
    /// `(local)` marker when the side was defaulted — but never the
    /// representative cities. Used by the result's place label, which the
    /// design sets uppercase and letterspaced, where
    /// `IN EASTERN TIME (NEW YORK, TORONTO)` would run off the screen.
    var shortPlaceDescription: String {
        isDeviceLocalZone ? "\(zoneDisplayName) (local)" : zoneDisplayName
    }

    /// `8:00 PM` — the design sets the meridiem in caps.
    var uppercasedTime: String { formattedTime.uppercased() }

    /// `4:00` from `4:00 pm`: the part the design sets at poster scale.
    var clockDigits: String {
        String(formattedTime.split(separator: " ").first ?? "")
    }

    /// `PM` from `4:00 pm`: the part that sits small beside the digits.
    var uppercasedMeridiem: String {
        String(formattedTime.split(separator: " ").last ?? "").uppercased()
    }
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
    /// marker appended when there is one. Abbreviation-resolved sides expand —
    /// see `ZoneReading.echoDescription`.
    var summary: String {
        let line = "\(source.echoDescription) → \(target.echoDescription)"
        guard let dayRolloverMarker else { return line }
        return "\(line) \(dayRolloverMarker)"
    }

    /// The rollover in words rather than in `+1d` shorthand, for the redesigned
    /// layout's offset line (`UTC+9 · next day`), where there is no echo
    /// sentence to hang a marker off.
    var dayRolloverNote: String? {
        switch dayOffset {
        case 0: return nil
        case 1: return "next day"
        case -1: return "previous day"
        default: return dayOffset > 0 ? "+\(dayOffset) days" : "\(dayOffset) days"
        }
    }

    /// The footer sentence (spec amendment 2026-10-23): how the target sits
    /// relative to the source, named after the source.
    ///
    /// Derived from the two offsets **at the resolved instant**, not from the
    /// zones' standard offsets, so a conversion made while one side is on
    /// daylight saving and the other is not tells the truth for that day.
    var relativeOffsetSentence: String {
        RelativeOffsetFormatting.sentence(
            differenceInSeconds: target.utcOffsetSeconds - source.utcOffsetSeconds,
            sourcePlaceName: source.zoneDisplayName
        )
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
            representativeCities: zone.representativeCities,
            formattedTime: TimeFormatting.twelveHourDescription(
                hour: components.hour ?? 0,
                minute: components.minute ?? 0
            ),
            utcOffsetDescription: UTCOffsetFormatting.description(for: zone.timeZone, at: instant),
            utcOffsetSeconds: zone.timeZone.secondsFromGMT(for: instant),
            isDeviceLocalZone: zone.isDeviceLocalZone
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
