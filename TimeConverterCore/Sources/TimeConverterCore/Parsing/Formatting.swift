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

/// The zone's own name, for item 21's sub-line (`Brasilia Standard Time`).
///
/// A lookup in `ZoneNameTable` — the bundled snapshot of what iOS says — rather
/// than a live call to Foundation. Asking the OS made the answer depend on the
/// OS: the iOS 26 simulator says `Australian Eastern Time` where macOS 26 says
/// `Eastern Australia Time`, and Android's `java.time` says `London Time`.
/// There must be one canonical answer, and iOS is the origin, so the snapshot
/// is a mechanical capture of iOS's answer for every identifier (nobody names
/// 443 zones by hand), hand-editable where iOS's wording reads badly.
enum ZoneNameFormatting {
    /// The locale the snapshot was captured in. Pinned, like every other
    /// string this app renders: every label is hand-written English, so a zone
    /// name that localised itself would be the one translated word on the
    /// screen. If the app is ever localised, this and the snapshot change
    /// together.
    static let locale = Locale(identifier: "en_US")

    /// `.generic` rather than `.standard` (the form the snapshot captures):
    ///
    /// | identifier         | `.generic`                | `.standard`                     |
    /// |--------------------|---------------------------|---------------------------------|
    /// | `America/New_York` | Eastern Time              | Eastern Standard Time           |
    /// | `Europe/London`    | United Kingdom Time       | Greenwich Mean Time             |
    /// | `America/Sao_Paulo`| Brasilia Standard Time    | Brasilia Standard Time          |
    /// | `Asia/Tokyo`       | Japan Standard Time       | Japan Standard Time             |
    ///
    /// `.standard` is actively wrong half the year — a London conversion in
    /// July is not on Greenwich Mean Time — and the sub-line is naming the
    /// *zone*, not today's offset within it.
    static func genericName(for timeZone: TimeZone) -> String {
        guard let name = ZoneNameTable.genericName(forIdentifier: timeZone.identifier),
              !name.isEmpty
        else {
            // An identifier newer than the snapshot: a quiet, readable
            // degradation. `ZoneNameSnapshotTests` fails until it is regenerated.
            return "\(ZoneDisplayName.forIdentifier(timeZone.identifier)) Time"
        }
        return name
    }

    /// What the running OS itself says — used only to *capture* the snapshot
    /// (`ZoneNameSnapshotTests` in regenerate mode), never to render.
    static func operatingSystemGenericName(for timeZone: TimeZone) -> String? {
        timeZone.localizedName(for: .generic, locale: locale)
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

/// The footer sentence (spec amendment 2026-10-23, from the iOS design;
/// **re-worded 2026-10-23** by the iPad/Mac designs):
/// `São Paulo is 4 hours behind Lisbon.` /
/// `London is 3 hours ahead of New York.` /
/// `Madrid is the same time as Paris.`
///
/// ## Why the target is now named
///
/// The iPhone design wrote this as a bare predicate — `4 hours behind Lisbon.`
/// — because on that screen it sits directly under one huge time, and the
/// subject is unmistakable. Pages 2–4 of `Time Converter-selection.pdf` put
/// **two** times side by side, and under two times "4 hours behind Lisbon"
/// stops being a sentence about the result and becomes a riddle about which
/// column it belongs to. The designs answer it by naming the subject.
///
/// Adopted everywhere rather than per platform (working assumption 2 of
/// `docs/sprint-plan-ipad-mac.md`): one sentence, one implementation, and the
/// iPhone reads no worse for having a subject.
///
/// Hand-rolled for the same reason as everything else in this file: the shape
/// is pinned by the spec, and a `NumberFormatter` would render `4.5` as `4,5`
/// on a comma-decimal device.
enum RelativeOffsetFormatting {
    /// `differenceInSeconds` is the **target** offset minus the **source**
    /// offset at the resolved instant, so a positive number means the target is
    /// ahead. Both names are the sides' display names, which is what keeps the
    /// sentence agreeing with the two column headers above it.
    static func sentence(
        differenceInSeconds: Int,
        targetPlaceName: String,
        sourcePlaceName: String
    ) -> String {
        guard differenceInSeconds != 0 else {
            // `London is the same time as London.` is what naming the subject
            // does to a conversion from a zone to itself, and it reads as a
            // bug rather than as an answer. The bare predicate the iPhone used
            // to print is kept for exactly this case — there is no ambiguity
            // about which column it describes when both columns say the same
            // word.
            guard targetPlaceName != sourcePlaceName else {
                return "Same time as \(sourcePlaceName)."
            }
            return "\(targetPlaceName) is the same time as \(sourcePlaceName)."
        }
        let direction = differenceInSeconds > 0 ? "ahead of" : "behind"
        let magnitude = hourCountDescription(seconds: abs(differenceInSeconds))
        return "\(targetPlaceName) is \(magnitude) \(direction) \(sourcePlaceName)."
    }

    /// The same relationship with both names stripped out: `4 hours behind`,
    /// `3 hours ahead`, `Same time`.
    ///
    /// Page 4's labeled arrow (`docs/design/Time Converter-selection.pdf`) sets
    /// this under the arrow between the two columns, where the keyboard has
    /// taken the room the full sentence needs. It works there precisely because
    /// the arrow is already pointing from the source to the target, so the
    /// phrase needs no subject and no object.
    ///
    /// Note `ahead` rather than the sentence's `ahead of`: with nothing
    /// following it, the preposition would be left dangling.
    static func phrase(differenceInSeconds: Int) -> String {
        guard differenceInSeconds != 0 else { return "Same time" }
        let direction = differenceInSeconds > 0 ? "ahead" : "behind"
        return "\(hourCountDescription(seconds: abs(differenceInSeconds))) \(direction)"
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
