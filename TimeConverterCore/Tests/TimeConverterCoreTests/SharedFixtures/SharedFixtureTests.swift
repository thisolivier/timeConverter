import Testing
import Foundation
@testable import TimeConverterCore

/// Keeps `fixtures/conversion-cases.json` and this core in agreement.
///
/// Two modes, one suite:
///
/// - **Verify** (the default): every case in the file must still produce
///   exactly the stored outcome, and the file must contain exactly the
///   catalog's cases in order. A behaviour change on the Apple side therefore
///   fails here until the fixtures are regenerated — which is the moment to
///   remember the Android core has to follow.
/// - **Regenerate** (`TIMECONVERTER_REGENERATE_FIXTURES=1`, via
///   `scripts/regenerate-fixtures.sh`): rewrite the file from the catalog.
///
/// The file is found relative to this source file, so the suite needs no
/// working-directory assumptions whichever lane runs it.
struct SharedFixtureTests {
    static let schemaVersion = 1
    static let generatedBy = "TimeConverterCore SharedFixtureTests (Swift)"

    static var fixtureFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // the file itself
            .deletingLastPathComponent() // SharedFixtures
            .deletingLastPathComponent() // TimeConverterCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // TimeConverterCore
            .appendingPathComponent("fixtures/conversion-cases.json")
    }

    static var isRegenerating: Bool {
        ProcessInfo.processInfo.environment["TIMECONVERTER_REGENERATE_FIXTURES"] == "1"
    }

    @Test func fixtureFileMatchesTheCatalogAndThisCore() throws {
        let generated = Self.render(Self.SharedFixtureCatalogEntries)
        if Self.isRegenerating {
            try Self.write(generated)
            return
        }
        let stored = try Self.read()
        #expect(stored.schemaVersion == Self.schemaVersion)
        #expect(stored.cases.map(\.id) == generated.cases.map(\.id),
                "catalog and fixture file list different cases — run scripts/regenerate-fixtures.sh")
        for (storedCase, generatedCase) in zip(stored.cases, generated.cases)
        where Self.platformNeutral(storedCase) != Self.platformNeutral(generatedCase) {
            Issue.record("fixture `\(storedCase.id)` is stale — run scripts/regenerate-fixtures.sh\n  stored: \(storedCase.expected)\n  now:    \(generatedCase.expected)")
        }
    }

    @Test func catalogIdentifiersAreUnique() {
        let identifiers = Self.SharedFixtureCatalogEntries.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
    }

    // MARK: - Platform-neutral comparison

    /// The one segment of a display that the OS supplies rather than this
    /// code: the generic zone name on a place-labelled zone line
    /// (`ZoneNameFormatting.genericName`). ICU versions disagree about it —
    /// the iOS 26 simulator says `Australian Eastern Time` where macOS 26 says
    /// `Eastern Australia Time` — so the fixtures carry whatever the generating
    /// Mac said and every verifier (this one and the Kotlin one) compares the
    /// line with that name wildcarded. Everything after the name — the cities
    /// and the rollover note — is this code's and stays exact.
    static func platformNeutral(_ conversionCase: ConversionCase) -> ConversionCase {
        var neutral = conversionCase
        if var display = neutral.expected.display {
            display.sourceZoneLine = neutralZoneLine(display.sourceZoneLine)
            display.targetZoneLine = neutralZoneLine(display.targetZoneLine)
            neutral.expected.display = display
        }
        return neutral
    }

    /// `Eastern Australia Time (Sydney, Melbourne) · previous day`
    /// → `* (Sydney, Melbourne) · previous day`. Abbreviation-labelled lines
    /// (`New York, Toronto`) have no parenthesis and pass through unchanged.
    static func neutralZoneLine(_ line: String) -> String {
        guard let parenthesis = line.range(of: " (") else { return line }
        return "*" + line[parenthesis.lowerBound...]
    }

    // MARK: - Rendering

    static var SharedFixtureCatalogEntries: [SharedFixtureCatalog.Entry] { SharedFixtureCatalog.entries }

    static func render(_ entries: [SharedFixtureCatalog.Entry]) -> ConversionCaseFile {
        ConversionCaseFile(
            schemaVersion: schemaVersion,
            generatedBy: generatedBy,
            cases: entries.map(render)
        )
    }

    static func render(_ entry: SharedFixtureCatalog.Entry) -> ConversionCase {
        ConversionCase(
            id: entry.id,
            input: entry.input,
            now: entry.now.formatted(.iso8601),
            localZone: entry.localZone.identifier,
            note: entry.note,
            expected: expectedOutcome(for: entry)
        )
    }

    static func expectedOutcome(for entry: SharedFixtureCatalog.Entry) -> ExpectedOutcome {
        let presenter = ConverterPresenter()
        let evaluation = presenter.evaluate(entry.input, now: entry.now, localZone: entry.localZone)
        switch evaluation {
        case .hint:
            return ExpectedOutcome(kind: "hint", chips: [])

        case let .converted(display):
            // The display carries no identifiers, so run the parse once more
            // for the resolved request underneath it.
            guard case let .result(result) = InputParser()
                .parseAndConvert(entry.input, now: entry.now, localZone: entry.localZone)
            else { preconditionFailure("presenter converted but parser did not: \(entry.id)") }
            return ExpectedOutcome(
                kind: "conversion",
                sourceZone: result.source.timeZoneIdentifier,
                targetZone: result.target.timeZoneIdentifier,
                requestedTime: twentyFourHour(result.requestedTime),
                dayOffset: result.dayOffset,
                display: expectedDisplay(display),
                chips: []
            )

        case let .prompt(prompt):
            let problem = presenter.problem(for: prompt)
            return ExpectedOutcome(
                kind: "prompt",
                promptId: prompt.specIdentifier,
                message: problem.message,
                chips: problem.chips.map {
                    ExpectedChip(
                        label: $0.label,
                        replacementText: $0.replacementText,
                        replacementStart: $0.replacementRange.startOffset,
                        replacementEnd: $0.replacementRange.endOffset
                    )
                }
            )
        }
    }

    static func expectedDisplay(_ display: ConverterDisplay) -> ExpectedDisplay {
        ExpectedDisplay(
            echoLine: display.echoLine,
            detailLine: display.detailLine,
            sourceEchoLine: display.sourceEchoLine,
            sourcePlaceName: display.sourcePlaceName,
            sourceClockDigits: display.sourceClockDigits,
            sourceMeridiem: display.sourceMeridiem,
            sourceZoneLine: display.sourceZoneLine,
            targetPlaceLabel: display.targetPlaceLabel,
            targetPlaceName: display.targetPlaceName,
            targetClockDigits: display.targetClockDigits,
            targetMeridiem: display.targetMeridiem,
            targetZoneLine: display.targetZoneLine,
            footerSentence: display.footerSentence,
            offsetPhrase: display.offsetPhrase,
            daylightSavingNote: display.daylightSavingNote
        )
    }

    /// `HH:mm` — the platform-neutral form; the 12-hour echo is already in the display.
    static func twentyFourHour(_ time: ParsedTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    // MARK: - File IO

    static func read() throws -> ConversionCaseFile {
        try JSONDecoder().decode(ConversionCaseFile.self, from: Data(contentsOf: fixtureFileURL))
    }

    static func write(_ file: ConversionCaseFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(file)
        data.append(contentsOf: [0x0A])
        try FileManager.default.createDirectory(
            at: fixtureFileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fixtureFileURL)
    }
}
