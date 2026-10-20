import Foundation

/// Deterministic, locale-independent formatting helpers.
///
/// These are hand-rolled rather than `DateFormatter`-based on purpose: the spec
/// pins exact output shapes (`12:00 pm`, `UTC-5`, `UTC+5:30`) and a
/// locale-driven formatter would render them differently on a device set to,
/// say, `de_DE` or a 24-hour locale. Hand formatting keeps the parser's output
/// identical everywhere and makes tests stable without injecting a `Locale`.

enum TimeFormatting {
    /// Renders a 24-hour (hour, minute) pair as the spec's canonical 12-hour
    /// echo form: no leading zero on the hour, zero-padded minutes, a space
    /// before a lowercase meridiem. Hour 0 → `12:00 am`, hour 12 → `12:00 pm`.
    static func twelveHourDescription(hour: Int, minute: Int) -> String {
        let hourWithinCycle = hour % 12
        let displayHour = hourWithinCycle == 0 ? 12 : hourWithinCycle
        let meridiem = hour < 12 ? "am" : "pm"
        let paddedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(displayHour):\(paddedMinute) \(meridiem)"
    }
}

enum GregorianCalendars {
    /// A Gregorian calendar pinned to a zone. Deliberately *not*
    /// `Calendar.current`: the user's calendar identifier and first-weekday
    /// settings must not change how a time converts.
    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static let utc = calendar(in: TimeZone(secondsFromGMT: 0)!)
}

enum ZoneDisplayName {
    /// Human-facing name for a tz identifier: the final path component with
    /// underscores turned into spaces (`America/New_York` → `New York`).
    /// Identifiers without a path component (`UTC`, `GMT`) pass through.
    static func forIdentifier(_ timeZoneIdentifier: String) -> String {
        let finalComponent = timeZoneIdentifier
            .split(separator: "/")
            .last
            .map(String.init) ?? timeZoneIdentifier
        return finalComponent.replacingOccurrences(of: "_", with: " ")
    }
}

enum UTCOffsetFormatting {
    /// Renders a zone's offset at a given instant the way the spec's examples
    /// do: `UTC+0`, `UTC-5`, and `UTC+5:30` only when the offset has minutes.
    static func description(for timeZone: TimeZone, at instant: Date) -> String {
        let totalSeconds = timeZone.secondsFromGMT(for: instant)
        let sign = totalSeconds < 0 ? "-" : "+"
        let absoluteSeconds = abs(totalSeconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        guard minutes > 0 else { return "UTC\(sign)\(hours)" }
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "UTC\(sign)\(hours):\(paddedMinutes)"
    }
}
