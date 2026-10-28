import Testing
import Foundation
@testable import TimeConverterCore

/// Keeps `Resources/zone-names.json` — the iOS-origin zone-name snapshot every
/// platform renders from — complete, and is the tool that writes it.
///
/// - **Verify** (the default, both lanes): the snapshot names every identifier
///   the running OS knows *and* every identifier this core's own tables can
///   emit, with no empty value, and the bundled copy is the
///   file on disk. A tz-database update therefore fails here until the
///   snapshot is regenerated.
///
///   The second set matters because Apple's `knownTimeZoneIdentifiers` still
///   lists the legacy `Asia/Calcutta`, while the country and alias tables emit
///   the current `Asia/Kolkata` — which `TimeZone(identifier:)` accepts and
///   names, but which a capture of the known list alone would miss.
/// - **Regenerate**: rewrite the file from the running OS. Only ever on the
///   iOS simulator, via `scripts/regenerate-zone-names.sh` — iOS is the origin.
///   `xcodebuild test` does not pass environment variables into the test host,
///   so the mode is keyed on a marker file the script creates and removes
///   (the simulator can read and write host paths).
struct ZoneNameSnapshotTests {
    static var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // the file itself
            .deletingLastPathComponent() // SharedFixtures
            .deletingLastPathComponent() // TimeConverterCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // TimeConverterCore
    }

    static var snapshotFileURL: URL {
        repositoryRootURL.appendingPathComponent(
            "TimeConverterCore/Sources/TimeConverterCore/Resources/zone-names.json"
        )
    }

    static var regenerateMarkerURL: URL {
        repositoryRootURL.appendingPathComponent("fixtures/.regenerate-zone-names")
    }

    static var isRegenerating: Bool {
        FileManager.default.fileExists(atPath: regenerateMarkerURL.path)
    }

    @Test func snapshotNamesEveryKnownZone() throws {
        if Self.isRegenerating {
            try Self.write(Self.capturedFromOperatingSystem())
            return
        }
        let stored = try Self.read()
        let missingIdentifiers = Self.identifiersToName.filter { stored[$0] == nil }
        #expect(missingIdentifiers.isEmpty,
                "zone-names.json lacks \(missingIdentifiers) — run scripts/regenerate-zone-names.sh")
        let emptyIdentifiers = stored.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys
        #expect(emptyIdentifiers.isEmpty, "empty names for \(emptyIdentifiers.sorted())")
    }

    @Test func bundledTableIsTheFileOnDisk() throws {
        if Self.isRegenerating { return }
        #expect(ZoneNameTable.namesByIdentifier == (try Self.read()),
                "the bundled snapshot differs from the source file — is it registered in Package.swift?")
    }

    @Test func formatterReadsTheSnapshot() throws {
        if Self.isRegenerating { return }
        let stored = try Self.read()
        for identifier in ["America/New_York", "Europe/London", "Australia/Sydney"] {
            #expect(ZoneNameFormatting.genericName(for: TimeZone(identifier: identifier)!) == stored[identifier])
        }
    }

    // MARK: - Capture and file IO

    /// Every identifier the app can render a zone line for: the OS's known
    /// list plus everything the core's own tables resolve to.
    static var identifiersToName: [String] {
        var identifiers = Set(TimeZone.knownTimeZoneIdentifiers)
        identifiers.formUnion(CountryZoneTable.zonesByCountryName.values.flatMap(\.candidateIdentifiers))
        identifiers.formUnion(AliasZoneTable.identifiersByAlias.values.joined())
        identifiers.formUnion(OfflineFallbackGazetteer.bundledEntries.values.joined())
        identifiers.formUnion(ZoneRepresentativeCities.curatedCitiesByIdentifier.keys)
        return identifiers.sorted()
    }

    static func capturedFromOperatingSystem() -> [String: String] {
        var namesByIdentifier: [String: String] = [:]
        for identifier in identifiersToName {
            guard let timeZone = TimeZone(identifier: identifier) else { continue }
            let name = ZoneNameFormatting.operatingSystemGenericName(for: timeZone) ?? ""
            namesByIdentifier[identifier] = name.isEmpty
                ? "\(ZoneDisplayName.forIdentifier(identifier)) Time"
                : name
        }
        return namesByIdentifier
    }

    static func read() throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: Data(contentsOf: snapshotFileURL))
    }

    static func write(_ namesByIdentifier: [String: String]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(namesByIdentifier)
        data.append(contentsOf: [0x0A])
        try data.write(to: snapshotFileURL)
    }
}
