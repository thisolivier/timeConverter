import Foundation
@testable import TimeConverter

/// Shared fixtures and pattern-matching sugar for the parsing tests.
///
/// Every conversion test injects a date from `FixedDates` — never `Date()` — so
/// assertions about UTC offsets and DST stay true forever.
enum FixedDates {
    static func utc(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    /// Northern-hemisphere winter: New York is UTC-5, London UTC+0 — the
    /// offsets the spec's own output example uses.
    static let winterMidday = utc(year: 2026, month: 1, day: 15)

    /// Northern-hemisphere summer: New York UTC-4, London UTC+1.
    static let summerMidday = utc(year: 2026, month: 7, day: 15)

    /// US clocks go forward at 2026-03-08 07:00 UTC — local 02:00 EST becomes
    /// 03:00 EDT, so 02:00–02:59 never happens in New York that day.
    static let newYorkSpringForwardDay = utc(year: 2026, month: 3, day: 8)

    /// US clocks go back at 2026-11-01 06:00 UTC — local 01:00–01:59 happens
    /// twice in New York that day.
    static let newYorkFallBackDay = utc(year: 2026, month: 11, day: 1)

    /// UK clocks go forward at 2026-03-29 01:00 UTC — local 01:00–01:59 never
    /// happens in London that day.
    static let londonSpringForwardDay = utc(year: 2026, month: 3, day: 29)
}

/// The production chain, including the real bundled gazetteer — so the Porto
/// fixtures genuinely exercise resource bundling rather than a stub.
func makeParser() -> InputParser {
    InputParser()
}

/// Builds a request straight from identifiers, for engine tests that don't care
/// about parsing.
func makeRequest(
    hour: Int,
    minute: Int = 0,
    from sourceIdentifier: String,
    to targetIdentifier: String,
    now: Date
) -> ConversionRequest {
    ConversionRequest(
        time: ParsedTime(hour: hour, minute: minute),
        sourceZone: makeZone(sourceIdentifier),
        targetZone: makeZone(targetIdentifier),
        referenceDate: now
    )
}

func makeZone(_ identifier: String) -> ResolvedZone {
    ResolvedZone(
        timeZone: TimeZone(identifier: identifier)!,
        displayName: ZoneDisplayName.forIdentifier(identifier),
        matchSource: .timeZoneDatabaseCity,
        originalToken: identifier.lowercased()
    )
}

extension ConversionOutcome {
    var resultValue: ConversionResult? {
        guard case let .result(result) = self else { return nil }
        return result
    }

    var promptValue: Prompt? {
        guard case let .prompt(prompt) = self else { return nil }
        return prompt
    }
}

extension ParseOutcome {
    var requestValue: ConversionRequest? {
        guard case let .request(request) = self else { return nil }
        return request
    }

    var promptValue: Prompt? {
        guard case let .prompt(prompt) = self else { return nil }
        return prompt
    }
}

extension Prompt {
    var ambiguousChoices: [ZoneChoice]? {
        guard case let .ambiguousZone(_, _, _, choices) = self else { return nil }
        return choices
    }

    var offendingToken: String? {
        switch self {
        case let .ambiguousZone(token, _, _, _): return token
        case let .unknownZone(token, _, _): return token
        case let .missingTargetZone(_, sourceZoneToken): return sourceZoneToken
        default: return nil
        }
    }

    var side: ZoneSide? {
        switch self {
        case let .ambiguousZone(_, side, _, _): return side
        case let .unknownZone(_, side, _): return side
        default: return nil
        }
    }
}

// MARK: - Raw ranges

/// The range of the first occurrence of `token` in `rawInput`, written the way
/// a reader checks it: by naming the substring rather than counting characters.
func rawRange(of token: String, in rawInput: String) -> RawTextRange {
    guard let found = rawInput.range(of: token) else {
        return RawTextRange(startOffset: 0, endOffset: 0)
    }
    return RawTextRange(
        startOffset: rawInput.distance(from: rawInput.startIndex, to: found.lowerBound),
        endOffset: rawInput.distance(from: rawInput.startIndex, to: found.upperBound)
    )
}

// MARK: - Display state

extension ConverterDisplayState {
    var problemMessage: String? {
        guard case let .problem(problem) = self else { return nil }
        return problem.message
    }

    var problemChips: [ReplacementChip]? {
        guard case let .problem(problem) = self else { return nil }
        return problem.chips
    }

    var convertedDisplay: ConverterDisplay? {
        guard case let .converted(display) = self else { return nil }
        return display
    }
}

/// A `.problem` state with no chips — the shape P1–P3 always take, and the
/// spelling the pre-chip tests used.
func plainProblem(_ message: String) -> ConverterDisplayState {
    .problem(ConverterProblem(message: message))
}
