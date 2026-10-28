import Testing
import Foundation
@testable import TimeConverterCore

/// Keeps `fixtures/world-clock-cases.json` and this core in agreement — the
/// world-clock twin of `SharedFixtureTests`, with the same two modes on the
/// same switch (`TIMECONVERTER_REGENERATE_FIXTURES=1`, set by
/// `scripts/regenerate-fixtures.sh`, which regenerates both files).
///
/// Verify mode checks both directions: the catalog renders to exactly the
/// stored file, and every stored case's *own* favourites and offset, decoded
/// from the file, produce its stored expectation — which is what the Android
/// port will do.
struct SharedWorldClockFixtureTests {
    static let schemaVersion = 1
    static let generatedBy = "TimeConverterCore SharedWorldClockFixtureTests (Swift)"

    static var fixtureFileURL: URL {
        SharedFixtureTests.fixtureFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("world-clock-cases.json")
    }

    @Test func fixtureFileMatchesTheCatalogAndThisCore() throws {
        let generated = Self.render(SharedWorldClockCatalog.entries)
        if SharedFixtureTests.isRegenerating {
            try Self.write(generated)
            return
        }
        let stored = try JSONDecoder().decode(WorldClockCaseFile.self, from: Data(contentsOf: Self.fixtureFileURL))
        #expect(stored.schemaVersion == Self.schemaVersion)
        #expect(stored.cases.map(\.id) == generated.cases.map(\.id),
                "catalog and fixture file list different cases — run scripts/regenerate-fixtures.sh")
        for (storedCase, generatedCase) in zip(stored.cases, generated.cases) where storedCase != generatedCase {
            Issue.record("world-clock fixture `\(storedCase.id)` is stale — run scripts/regenerate-fixtures.sh\n  stored: \(storedCase)\n  now:    \(generatedCase)")
        }
        for storedCase in stored.cases {
            #expect(try Self.expectation(replaying: storedCase) == storedCase.expected, "\(storedCase.id)")
        }
    }

    @Test func catalogIdentifiersAreUniqueAndEveryFavouriteResolves() {
        let identifiers = SharedWorldClockCatalog.entries.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
        for entry in SharedWorldClockCatalog.entries {
            #expect(Self.favourites(for: entry).count == entry.favouriteZones.count, "\(entry.id)")
        }
    }

    // MARK: - Rendering

    static func favourites(for entry: SharedWorldClockCatalog.Entry) -> [FavouriteDestination] {
        entry.favouriteZones.compactMap(FavouriteDestination.resolvingTypedZone)
    }

    static func render(_ entries: [SharedWorldClockCatalog.Entry]) -> WorldClockCaseFile {
        WorldClockCaseFile(schemaVersion: schemaVersion, generatedBy: generatedBy, cases: entries.map(render))
    }

    static func render(_ entry: SharedWorldClockCatalog.Entry) -> WorldClockCase {
        let favourites = favourites(for: entry)
        let display = WorldClock.readings(
            favourites: favourites,
            offset: TimeInterval(entry.offsetMinutes * 60),
            now: entry.now,
            localZone: entry.localZone
        )
        return WorldClockCase(
            id: entry.id,
            note: entry.note,
            now: entry.now.formatted(.iso8601),
            localZone: entry.localZone.identifier,
            offsetSeconds: entry.offsetMinutes * 60,
            favourites: favourites.map(fixtureFavourite),
            expected: expected(display)
        )
    }

    /// Replays a stored case from its own inputs, as a second implementation would.
    static func expectation(replaying storedCase: WorldClockCase) throws -> ExpectedWorldClock {
        let now = try Date(storedCase.now, strategy: .iso8601)
        let localZone = try #require(TimeZone(identifier: storedCase.localZone))
        let favourites = try storedCase.favourites.map(destination)
        return expected(WorldClock.readings(
            favourites: favourites, offset: TimeInterval(storedCase.offsetSeconds), now: now, localZone: localZone
        ))
    }

    static func expected(_ display: WorldClockDisplay) -> ExpectedWorldClock {
        ExpectedWorldClock(
            readout: display.readout,
            offsetDescription: display.offsetDescription,
            rows: display.rows.map {
                ExpectedWorldClockRow(
                    isLocal: $0.isLocal, placeName: $0.placeName, clockDigits: $0.clockDigits,
                    meridiem: $0.meridiem, zoneLine: $0.zoneLine, offsetPhrase: $0.offsetPhrase
                )
            }
        )
    }

    static func fixtureFavourite(_ destination: FavouriteDestination) -> WorldClockFixtureFavourite {
        switch destination.label {
        case let .place(name, _):
            return WorldClockFixtureFavourite(
                timeZoneIdentifier: destination.timeZoneIdentifier, labelKind: "place", name: name
            )
        case let .abbreviation(code, expandedName):
            return WorldClockFixtureFavourite(
                timeZoneIdentifier: destination.timeZoneIdentifier, labelKind: "code",
                code: code, expandedName: expandedName
            )
        }
    }

    static func destination(_ favourite: WorldClockFixtureFavourite) throws -> FavouriteDestination {
        let label: ZoneLabel = favourite.labelKind == "code"
            ? .abbreviation(code: try #require(favourite.code), expandedName: try #require(favourite.expandedName))
            : .place(name: try #require(favourite.name), isDeviceLocal: false)
        return FavouriteDestination(timeZoneIdentifier: favourite.timeZoneIdentifier, label: label)
    }

    static func write(_ file: WorldClockCaseFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(file)
        data.append(contentsOf: [0x0A])
        try data.write(to: fixtureFileURL)
    }
}
