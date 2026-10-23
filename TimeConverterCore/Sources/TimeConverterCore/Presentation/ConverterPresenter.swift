import Foundation

/// Glue between `InputParser` and the view.
///
/// Pure, and deliberately the only place where parse output becomes display
/// values — which is what makes the UI testable without any UI tests. `now` and
/// `localZone` are parameters here too; the view is the one place that calls
/// `Date()` and reads `TimeZone.current`.
struct ConverterPresenter: Sendable {
    private let parser: InputParser

    init(parser: InputParser = InputParser()) {
        self.parser = parser
    }

    /// What an input produces, *before* the expensive part.
    ///
    /// Split out for item 8's debounce: the driver needs to know whether an
    /// edit yields a result (show it now) or a prompt (hold it back) without
    /// paying for the did-you-mean vocabulary scan on every keystroke. The scan
    /// happens in `problem(for:)`, once the prompt is actually due.
    enum Evaluation: Equatable, Sendable {
        case hint
        case converted(ConverterDisplay)
        case prompt(Prompt)
    }

    func evaluate(_ rawInput: String, now: Date, localZone: TimeZone) -> Evaluation {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty input stays quiet rather than scolding the user with P1 before
        // they have typed anything.
        guard !trimmedInput.isEmpty else { return .hint }

        switch parser.parseAndConvert(rawInput, now: now, localZone: localZone) {
        case let .result(result):
            return .converted(Self.display(for: result))
        case let .prompt(prompt):
            return .prompt(prompt)
        }
    }

    func displayState(for evaluation: Evaluation) -> ConverterDisplayState {
        switch evaluation {
        case .hint: return .hint
        case let .converted(display): return .converted(display)
        case let .prompt(prompt): return .problem(problem(for: prompt))
        }
    }

    func displayState(
        for rawInput: String,
        now: Date,
        localZone: TimeZone
    ) -> ConverterDisplayState {
        displayState(for: evaluate(rawInput, now: now, localZone: localZone))
    }

    // MARK: - Rendering

    static func display(for result: ConversionResult) -> ConverterDisplay {
        let note = daylightSavingNote(for: result)
        var detailLine = "\(result.source.timeZoneIdentifier) → \(result.target.timeZoneIdentifier)"
        if let note {
            detailLine += " · \(note)"
        }
        return ConverterDisplay(
            echoLine: result.summary,
            detailLine: detailLine,
            sourceEchoLine: sourceEchoLine(for: result),
            targetPlaceLabel: "In \(result.target.shortPlaceDescription)",
            targetClockDigits: result.target.clockDigits,
            targetMeridiem: result.target.uppercasedMeridiem,
            targetOffsetLine: targetOffsetLine(for: result),
            footerSentence: result.relativeOffsetSentence,
            daylightSavingNote: note
        )
    }

    /// `Lisbon · 8:00 PM · UTC+1`, the line the design puts *inside* the input
    /// box under a hairline rule — the source side only, because the target
    /// side is the whole bottom half of the screen.
    static func sourceEchoLine(for result: ConversionResult) -> String {
        [
            result.source.placeDescription,
            result.source.uppercasedTime,
            result.source.utcOffsetDescription,
        ].joined(separator: " · ")
    }

    static func targetOffsetLine(for result: ConversionResult) -> String {
        guard let rollover = result.dayRolloverNote else {
            return result.target.utcOffsetDescription
        }
        return "\(result.target.utcOffsetDescription) · \(rollover)"
    }

    /// Explains the DST policy in passing, on the two days a year it applies.
    /// Without this the echoed time silently differs from what was typed.
    ///
    /// Names the plain city even when the echo line expanded an abbreviation:
    /// "doesn't exist today in New York" reads; "in Eastern Time (New York,
    /// Toronto)" does not.
    static func daylightSavingNote(for result: ConversionResult) -> String? {
        let requestedTime = result.requestedTime.canonicalDescription
        let city = result.source.cityName
        switch result.wallClockDisposition {
        case .unambiguous:
            return nil
        case .nonexistentTimeShiftedForward:
            return "\(requestedTime) doesn't exist today in \(city) — clocks went forward"
        case .repeatedTimeTookEarlier:
            return "\(requestedTime) happens twice today in \(city) — showing the first"
        }
    }

    // MARK: - Prompts

    /// Prompts render as their spec copy, unchanged — styling and wording are
    /// deliberately not part of this sprint. What *is* new is the chip row: P4
    /// offers its candidates and P5 its did-you-mean suggestions as taps that
    /// rewrite the offending token in the sentence.
    func problem(for prompt: Prompt) -> ConverterProblem {
        ConverterProblem(message: Self.problemLine(for: prompt), chips: chips(for: prompt))
    }

    /// P4 additionally lists its candidates inline. Redundant now that the
    /// chips are tappable, but the interim copy is explicitly staying as-is
    /// until the design sprint, and it is also what a user reading aloud or
    /// screenshotting sees.
    static func problemLine(for prompt: Prompt) -> String {
        guard case let .ambiguousZone(_, _, _, choices) = prompt, !choices.isEmpty else {
            return prompt.message
        }
        let candidateList = choices
            .map { "\($0.representativeCity) (\($0.utcOffsetDescription))" }
            .joined(separator: ", ")
        return "\(prompt.message): \(candidateList)"
    }

    func chips(for prompt: Prompt) -> [ReplacementChip] {
        switch prompt {
        case let .ambiguousZone(_, _, tokenRange, choices):
            return choices.map { choice in
                ReplacementChip(
                    label: "\(choice.representativeCity) (\(choice.utcOffsetDescription))",
                    replacementText: choice.representativeCity,
                    replacementRange: tokenRange
                )
            }

        case let .unknownZone(token, _, tokenRange):
            // Never auto-accepted, not even a unique distance-1 match — the tap
            // is the whole point. See `ZoneSuggestionEngine`'s policy.
            return ZoneSuggestionEngine
                .suggestions(for: token, in: parser.zoneResolverChain)
                .map { suggestion in
                    ReplacementChip(
                        label: "\(suggestion.label)?",
                        replacementText: suggestion.label,
                        replacementRange: tokenRange
                    )
                }

        case .timeNotFound, .zoneNotFound:
            return []
        }
    }
}
