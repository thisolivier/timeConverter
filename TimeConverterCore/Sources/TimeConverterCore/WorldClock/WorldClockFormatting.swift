import Foundation

/// The readout's two strings, hand-rolled and locale-independent like
/// everything in `Formatting.swift`: a device set to German still reads
/// `Fri 31 Oct, 9:15 AM`, matching every other English label in the app.
enum WorldClockFormatting {
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    /// A true minus, as the spec writes `−45 min`.
    static let minusSign = "\u{2212}"

    /// `Today 2:30 PM`, `Tomorrow 9:15 AM`, `Yesterday 11:00 PM`, or
    /// `Fri 31 Oct, 9:15 AM` beyond one day either way.
    static func readout(
        dayDifference: Int,
        shiftedInstant: Date,
        localZone: TimeZone,
        uppercasedTime: String
    ) -> String {
        switch dayDifference {
        case 0: return "Today \(uppercasedTime)"
        case 1: return "Tomorrow \(uppercasedTime)"
        case -1: return "Yesterday \(uppercasedTime)"
        default:
            let components = GregorianCalendars.calendar(in: localZone)
                .dateComponents([.weekday, .day, .month], from: shiftedInstant)
            let weekday = weekdayNames[((components.weekday ?? 1) - 1) % 7]
            let month = monthNames[((components.month ?? 1) - 1) % 12]
            return "\(weekday) \(components.day ?? 1) \(month), \(uppercasedTime)"
        }
    }

    /// `+00d 04h 00m`, `−01d 12h 30m`; `nil` at zero, where the readout says
    /// `Now`. Every part is always present and zero-padded (the 2026-11-04
    /// design's form) so the string keeps one width while the dial turns —
    /// dropping zero parts, as build 20 did, made the label flicker between
    /// `+5 h` and `+4 h 45 min` under the finger (Olivier, 2026-11-04).
    static func offsetDescription(minutes: Int) -> String? {
        guard minutes != 0 else { return nil }
        let magnitude = abs(minutes)
        let days = magnitude / 1440
        let hours = (magnitude % 1440) / 60
        let remainingMinutes = magnitude % 60
        func padded(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return (minutes > 0 ? "+" : minusSign)
            + "\(padded(days))d \(padded(hours))h \(padded(remainingMinutes))m"
    }
}
