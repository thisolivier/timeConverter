import Foundation

/// The time half of the grammar:
///
/// ```
/// <time> := H[H]:mm                  (24-hour)
///         | H[H][:mm] [space] am|pm  (space optional)
/// ```
///
/// Matches only at the *start* of the (already normalised) input and hands back
/// whatever follows, so the tokenizer can go looking for the conjunction.
///
/// A meridiem on an hour above 12 is redundant rather than wrong: it is
/// accepted when it agrees with the hour (`18pm` = 18:00) and rejected when it
/// contradicts it (`13:00 am`). See `meridiemTime`.
enum TimeTokenParser {
    struct Match: Equatable, Sendable {
        let time: ParsedTime
        /// Everything after the matched time, with leading whitespace removed.
        let remainder: String
        /// Character offset, within the normalised input, at which `remainder`
        /// begins. Carried so the tokenizer can give every zone token an
        /// absolute range instead of re-deriving one by searching.
        let remainderStartOffset: Int
    }

    // These are computed rather than `static let` because `Regex` is not
    // `Sendable`, which Swift 6 forbids in stored static state. Rebuilding two
    // tiny patterns per parse is immeasurable next to a keystroke.

    /// Meridiem form. Minutes are optional (`12pm` = 12:00 pm) and the space
    /// before the meridiem is optional (`12pm`, `12 pm`, `12:30pm`, `12:30 pm`).
    /// The lookahead stops `12pmet` from matching as `12pm` + `et`.
    /// Hour range is validated in `meridiemTime`, which also decides whether a
    /// redundant meridiem agrees with its hour.
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
            // A meridiem that contradicts its hour (`13:00 am`) is a failed
            // time, not an invitation to retry as 24-hour — retrying would
            // parse `13:00` and quietly shove `am` into the zone token.
            guard let time = meridiemTime(
                hourText: hourText,
                minuteText: minuteText,
                meridiemText: meridiemText
            ) else { return nil }
            return match(time: time, in: normalizedInput, after: wholeMatch)
        }

        if let twentyFourHourMatch = try? twentyFourHourPattern.prefixMatch(in: normalizedInput) {
            let (wholeMatch, hourText, minuteText) = twentyFourHourMatch.output
            guard let hour = Int(hourText), let minute = Int(minuteText),
                  (0...23).contains(hour), (0...59).contains(minute)
            else { return nil }
            return match(
                time: ParsedTime(hour: hour, minute: minute),
                in: normalizedInput,
                after: wholeMatch
            )
        }

        return nil
    }

    // MARK: - Helpers

    /// Reads an hour that carried an `am`/`pm`.
    ///
    /// Hours 1–12 are an ordinary 12-hour clock, with the standard convention
    /// that `12 am` is midnight and `12 pm` is noon.
    ///
    /// Outside that range the meridiem is redundant, and the spec accepts it
    /// when it *agrees* with the hour and rejects it when it contradicts:
    /// `13:00 pm` and `18pm` simply mean 13:00 and 18:00, `0:30 am` means
    /// 00:30, while `13:00 am` and `0:30 pm` are nonsense and fail.
    private static func meridiemTime(
        hourText: Substring,
        minuteText: Substring?,
        meridiemText: Substring
    ) -> ParsedTime? {
        guard let statedHour = Int(hourText), (0...23).contains(statedHour) else { return nil }
        let minute = minuteText.flatMap { Int($0) } ?? 0
        guard (0...59).contains(minute) else { return nil }

        let isAfternoon = meridiemText == "pm"
        let hour: Int
        switch statedHour {
        case 0:
            // The midnight hour is an "am" hour; "pm" contradicts it.
            guard !isAfternoon else { return nil }
            hour = 0
        case 1...11:
            hour = isAfternoon ? statedHour + 12 : statedHour
        case 12:
            hour = isAfternoon ? 12 : 0
        default:
            // 13–23 already name an afternoon or evening hour, so "pm" merely
            // agrees while "am" contradicts.
            guard isAfternoon else { return nil }
            hour = statedHour
        }
        return ParsedTime(hour: hour, minute: minute)
    }

    /// Builds a `Match` from the matched time span, trimming the whitespace
    /// between the time and the rest of the sentence while keeping count of how
    /// many characters were skipped — that count is what makes the remainder's
    /// offsets absolute.
    private static func match(
        time: ParsedTime,
        in normalizedInput: String,
        after matched: Substring
    ) -> Match {
        let tail = normalizedInput[matched.endIndex...]
        let leadingWhitespaceCount = tail.prefix(while: { $0.isWhitespace }).count
        let remainder = tail.drop(while: { $0.isWhitespace })
        return Match(
            time: time,
            remainder: String(remainder).trimmingCharacters(in: .whitespaces),
            remainderStartOffset: normalizedInput.distance(
                from: normalizedInput.startIndex,
                to: matched.endIndex
            ) + leadingWhitespaceCount
        )
    }
}
