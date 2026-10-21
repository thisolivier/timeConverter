import Foundation

/// The module's entry point: freeform string in, either a conversion to run or
/// a prompt to show.
///
/// Pure by construction — `now` is injected rather than read from the clock, so
/// every outcome is reproducible in a test. The resolver chain is injectable
/// for the same reason.
struct InputParser: Sendable {
    let zoneResolverChain: ZoneResolverChain

    init(zoneResolverChain: ZoneResolverChain = .standard) {
        self.zoneResolverChain = zoneResolverChain
    }

    /// - Parameters:
    ///   - input: whatever the user typed.
    ///   - now: the caller's current `Date`. Used for two things only: deciding
    ///     which calendar day "today" is in the source zone, and computing the
    ///     UTC offsets shown in an ambiguity picker.
    func parse(_ input: String, now: Date) -> ParseOutcome {
        let tokens: InputTokenizer.Tokens
        switch InputTokenizer.tokenize(input) {
        case let .prompt(prompt):
            return .prompt(prompt)
        case let .tokens(tokenized):
            tokens = tokenized
        }

        // Resolved left to right, so a user with two bad tokens is asked about
        // the first one first rather than being shown an arbitrary choice.
        let sourceZone: ResolvedZone
        switch resolve(tokens.sourceZone, side: .source, now: now) {
        case let .prompt(prompt): return .prompt(prompt)
        case let .resolved(zone): sourceZone = zone
        }

        let targetZone: ResolvedZone
        switch resolve(tokens.targetZone, side: .target, now: now) {
        case let .prompt(prompt): return .prompt(prompt)
        case let .resolved(zone): targetZone = zone
        }

        return .request(ConversionRequest(
            time: tokens.time,
            sourceZone: sourceZone,
            targetZone: targetZone,
            referenceDate: now
        ))
    }

    // MARK: - Zone resolution

    /// One side's outcome. A local two-case enum rather than `Result`, which
    /// would need `Prompt` to be an `Error` — a prompt is not a failure.
    private enum ZoneStep {
        case resolved(ResolvedZone)
        case prompt(Prompt)
    }

    /// Takes the whole `ZoneToken`, not just its text, so the prompt it may
    /// produce can carry the raw range a correction chip has to rewrite.
    private func resolve(
        _ zoneToken: InputTokenizer.ZoneToken,
        side: ZoneSide,
        now: Date
    ) -> ZoneStep {
        switch zoneResolverChain.resolve(zoneToken.text) {
        case let .resolved(zone):
            return .resolved(zone)
        case let .ambiguous(candidates):
            return .prompt(.ambiguousZone(
                token: zoneToken.text,
                side: side,
                tokenRange: zoneToken.rawRange,
                choices: Self.choices(from: candidates, at: now)
            ))
        case .unknown:
            return .prompt(.unknownZone(
                token: zoneToken.text,
                side: side,
                tokenRange: zoneToken.rawRange
            ))
        }
    }

    /// Builds the picker rows the spec asks for: every candidate with a
    /// representative city and its UTC offset *at the injected date*, so the
    /// offsets are seasonally correct and still deterministic in tests.
    static func choices(from candidates: [ZoneCandidate], at instant: Date) -> [ZoneChoice] {
        candidates.compactMap { candidate in
            guard let timeZone = TimeZone(identifier: candidate.timeZoneIdentifier) else {
                return nil
            }
            return ZoneChoice(
                timeZoneIdentifier: candidate.timeZoneIdentifier,
                // The city, not the expanded abbreviation name: a chip's label
                // has to be something the user could also have typed, and
                // tapping it writes exactly this word into the sentence.
                representativeCity: candidate.representativeCityName,
                utcOffsetDescription: UTCOffsetFormatting.description(for: timeZone, at: instant)
            )
        }
    }
}

// MARK: - Parse and convert in one step

/// What the UI ultimately wants: a rendered result, or a prompt.
enum ConversionOutcome: Equatable, Sendable {
    case result(ConversionResult)
    case prompt(Prompt)
}

extension InputParser {
    /// Convenience composition of `parse` and `ConversionEngine.convert`, so
    /// item 4 doesn't have to re-implement the two-step dance.
    func parseAndConvert(
        _ input: String,
        now: Date,
        engine: ConversionEngine = ConversionEngine()
    ) -> ConversionOutcome {
        switch parse(input, now: now) {
        case let .prompt(prompt): return .prompt(prompt)
        case let .request(request): return .result(engine.convert(request))
        }
    }
}
