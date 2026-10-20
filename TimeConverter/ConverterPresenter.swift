import Foundation

/// The three things the UI can be showing.
enum ConverterDisplayState: Equatable, Sendable {
    /// Nothing typed yet — the quiet hint.
    case hint
    /// A successful conversion.
    case converted(ConverterDisplay)
    /// Any of P1–P5, rendered as a single plain line. This phase has no
    /// pickers, so even the ambiguity prompt is just text to read and retype
    /// against.
    case problem(String)
}

/// Pre-rendered strings for the output area, so the view holds no logic.
struct ConverterDisplay: Equatable, Sendable {
    /// The spec's canonical echo:
    /// `12:00 pm New York (UTC-5) → 5:00 pm London (UTC+0) +1d`.
    let echoLine: String
    /// Quieter supporting detail: the zones actually used, plus a note when the
    /// DST policy had to move the time.
    let detailLine: String
}

/// Glue between `InputParser` and the view.
///
/// Pure, and deliberately the only place where parse output becomes display
/// strings — which is what makes the UI testable without any UI tests. `now`
/// is a parameter here too; the view is the one place that calls `Date()`.
struct ConverterPresenter: Sendable {
    private let parser: InputParser

    init(parser: InputParser = InputParser()) {
        self.parser = parser
    }

    func displayState(for rawInput: String, now: Date) -> ConverterDisplayState {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty input stays quiet rather than scolding the user with P1 before
        // they have typed anything.
        guard !trimmedInput.isEmpty else { return .hint }

        switch parser.parseAndConvert(rawInput, now: now) {
        case let .result(result):
            return .converted(Self.display(for: result))
        case let .prompt(prompt):
            return .problem(Self.problemLine(for: prompt))
        }
    }

    // MARK: - Rendering

    static func display(for result: ConversionResult) -> ConverterDisplay {
        var detailLine = "\(result.source.timeZoneIdentifier) → \(result.target.timeZoneIdentifier)"
        if let note = daylightSavingNote(for: result) {
            detailLine += " · \(note)"
        }
        return ConverterDisplay(echoLine: result.summary, detailLine: detailLine)
    }

    /// Explains the DST policy in passing, on the two days a year it applies.
    /// Without this the echoed time silently differs from what was typed.
    static func daylightSavingNote(for result: ConversionResult) -> String? {
        let requestedTime = result.requestedTime.canonicalDescription
        let city = result.source.zoneDisplayName
        switch result.wallClockDisposition {
        case .unambiguous:
            return nil
        case .nonexistentTimeShiftedForward:
            return "\(requestedTime) doesn't exist today in \(city) — clocks went forward"
        case .repeatedTimeTookEarlier:
            return "\(requestedTime) happens twice today in \(city) — showing the first"
        }
    }

    /// Prompts render as their spec copy. P4 additionally lists its candidates
    /// inline, because there is no picker to tap — the user retypes using one
    /// of the names shown.
    static func problemLine(for prompt: Prompt) -> String {
        guard case let .ambiguousZone(_, _, choices) = prompt, !choices.isEmpty else {
            return prompt.message
        }
        let candidateList = choices
            .map { "\($0.representativeCity) (\($0.utcOffsetDescription))" }
            .joined(separator: ", ")
        return "\(prompt.message): \(candidateList)"
    }
}
