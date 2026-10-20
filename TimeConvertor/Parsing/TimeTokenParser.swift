import Foundation

/// The time half of the grammar:
///
/// ```
/// <time> := HH:mm                    (24-hour)
///         | H[H][:mm] [space] am|pm  (12-hour, space optional)
/// ```
///
/// Matches only at the *start* of the (already normalised) input and hands back
/// whatever follows, so the tokenizer can go looking for the conjunction.
enum TimeTokenParser {
    struct Match: Equatable, Sendable {
        let time: ParsedTime
        /// Everything after the matched time, with leading whitespace removed.
        let remainder: String
    }

    // These are computed rather than `static let` because `Regex` is not
    // `Sendable`, which Swift 6 forbids in stored static state. Rebuilding two
    // tiny patterns per parse is immeasurable next to a keystroke.

    /// 12-hour form. Minutes are optional (`12pm` = 12:00 pm) and the space
    /// before the meridiem is optional (`12pm`, `12 pm`, `12:30pm`, `12:30 pm`).
    /// The lookahead stops `12pmet` from matching as `12pm` + `et`.
    private static var twelveHourPattern: Regex<(Substring, Substring, Substring?, Substring)> {
        /(\d{1,2})(?::(\d{2}))?[ ]?([ap]m)(?=[ ]|$)/
    }

    /// 24-hour form. Minutes are mandatory here — a bare `6` is not a time, so
    /// `6 ET in London` is a P1, not an accidental 06:00.
    private static var twentyFourHourPattern: Regex<(Substring, Substring, Substring)> {
        /(\d{1,2}):(\d{2})(?=[ ]|$)/
    }

    /// Tries the 12-hour form first: it is the longer match wherever both could
    /// apply, so `9:30 am New York...` must not be read as 24-hour `9:30`
    /// followed by a zone token starting with "am".
    static func match(atStartOf normalizedInput: String) -> Match? {
        if let twelveHourMatch = try? twelveHourPattern.prefixMatch(in: normalizedInput) {
            let (wholeMatch, hourText, minuteText, meridiemText) = twelveHourMatch.output
            // A clear 12-hour intent with an impossible hour (`13:00 pm`) is a
            // failed time, not an invitation to retry as 24-hour.
            guard let time = twelveHourTime(
                hourText: hourText,
                minuteText: minuteText,
                meridiemText: meridiemText
            ) else { return nil }
            return Match(time: time, remainder: remainder(of: normalizedInput, after: wholeMatch))
        }

        if let twentyFourHourMatch = try? twentyFourHourPattern.prefixMatch(in: normalizedInput) {
            let (wholeMatch, hourText, minuteText) = twentyFourHourMatch.output
            guard let hour = Int(hourText), let minute = Int(minuteText),
                  (0...23).contains(hour), (0...59).contains(minute)
            else { return nil }
            return Match(
                time: ParsedTime(hour: hour, minute: minute),
                remainder: remainder(of: normalizedInput, after: wholeMatch)
            )
        }

        return nil
    }

    // MARK: - Helpers

    /// Applies the standard midnight/noon convention: `12 am` → 00:00 and
    /// `12 pm` → 12:00.
    private static func twelveHourTime(
        hourText: Substring,
        minuteText: Substring?,
        meridiemText: Substring
    ) -> ParsedTime? {
        guard let hourOnClockFace = Int(hourText), (1...12).contains(hourOnClockFace) else {
            return nil
        }
        let minute = minuteText.flatMap { Int($0) } ?? 0
        guard (0...59).contains(minute) else { return nil }

        let hourWithinCycle = hourOnClockFace == 12 ? 0 : hourOnClockFace
        let hour = meridiemText == "pm" ? hourWithinCycle + 12 : hourWithinCycle
        return ParsedTime(hour: hour, minute: minute)
    }

    private static func remainder(of normalizedInput: String, after matched: Substring) -> String {
        String(normalizedInput[matched.endIndex...])
            .trimmingCharacters(in: .whitespaces)
    }
}
