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

    /// `+5 h`, `−45 min`, `+3 d 2 h`, `+1 d 15 min`; `nil` at zero. Zero parts
    /// are dropped so the common cases stay short.
    static func offsetDescription(minutes: Int) -> String? {
        guard minutes != 0 else { return nil }
        let magnitude = abs(minutes)
        let days = magnitude / 1440
        let hours = (magnitude % 1440) / 60
        let remainingMinutes = magnitude % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days) d") }
        if hours > 0 { parts.append("\(hours) h") }
        if remainingMinutes > 0 { parts.append("\(remainingMinutes) min") }
        return (minutes > 0 ? "+" : minusSign) + parts.joined(separator: " ")
    }
}
