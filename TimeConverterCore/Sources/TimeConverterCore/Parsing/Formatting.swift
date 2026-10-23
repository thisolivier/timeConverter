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

/// The footer sentence (spec amendment 2026-10-23, from the iOS design):
/// `4 hours behind Lisbon.` / `3 hours ahead of New York.` /
/// `Same time as London.`
///
/// Hand-rolled for the same reason as everything else in this file: the shape
/// is pinned by the spec, and a `NumberFormatter` would render `4.5` as `4,5`
/// on a comma-decimal device.
enum RelativeOffsetFormatting {
    /// `differenceInSeconds` is the **target** offset minus the **source**
    /// offset at the resolved instant, so a positive number means the target is
    /// ahead. `sourcePlaceName` is the source's display name, which is what the
    /// sentence names.
    static func sentence(differenceInSeconds: Int, sourcePlaceName: String) -> String {
        guard differenceInSeconds != 0 else { return "Same time as \(sourcePlaceName)." }
        let direction = differenceInSeconds > 0 ? "ahead of" : "behind"
        let magnitude = hourCountDescription(seconds: abs(differenceInSeconds))
        return "\(magnitude) \(direction) \(sourcePlaceName)."
    }

    /// `1 hour`, `4 hours`, `4.5 hours`, `5.75 hours`.
    ///
    /// Two decimal places are exact rather than rounded: every zone offset in
    /// the database is a whole number of quarter-hours, so the fractional part
    /// is only ever `.25`, `.5` or `.75`. A trailing zero is dropped so a
    /// half-hour zone reads `4.5` and not `4.50`.
    static func hourCountDescription(seconds: Int) -> String {
        let wholeHours = seconds / 3600
        let remainderSeconds = seconds % 3600
        guard remainderSeconds != 0 else {
            return wholeHours == 1 ? "1 hour" : "\(wholeHours) hours"
        }
        let hundredthsOfAnHour = (remainderSeconds * 100) / 3600
        var fraction = hundredthsOfAnHour < 10
            ? "0\(hundredthsOfAnHour)"
            : "\(hundredthsOfAnHour)"
        if fraction.hasSuffix("0") { fraction.removeLast() }
        // Always plural: "0.5 hours", "1.5 hours" — only an exact 1 is singular.
        return "\(wholeHours).\(fraction) hours"
    }
}
