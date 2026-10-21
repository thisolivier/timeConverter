import Testing
import Foundation
@testable import TimeConverter

/// Step 5 of the chain, and — importantly — proof that the data file it reads
/// is actually bundled into the built product. That is a project-generation
/// concern as much as a code one, so it is asserted at runtime rather than
/// assumed.
struct OfflineFallbackGazetteerTests {
    @Test func gazetteerFileIsPresentInTheBundle() throws {
        let fileURL = try #require(
            OfflineFallbackGazetteer.bundledFileURL,
            "fallback-cities.json is not in the built bundle — check project.yml sources"
        )
        #expect(fileURL.lastPathComponent == "fallback-cities.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func bundledFileDecodesTheQASeedEntries() {
        #expect(OfflineFallbackGazetteer.bundledEntries["porto"] == ["Europe/Lisbon"])
        #expect(OfflineFallbackGazetteer.bundledEntries["manchester"] == ["Europe/London"])
    }

    /// The seed is deliberately tiny: QA entries plus the one modern city name
    /// this OS's tz database only ships under a link name. Anything else that
    /// happens to be a real city elsewhere still reports as unknown rather than
    /// silently resolving.
    @Test func seedContainsOnlyTheQAEntriesAndTheKolkataLinkFix() {
        #expect(Set(OfflineFallbackGazetteer.bundledEntries.keys)
            == ["porto", "manchester", "kolkata"])
    }

    /// `Asia/Kolkata` is a valid `TimeZone` identifier but is absent from this
    /// OS's `knownTimeZoneIdentifiers` (which carries `Asia/Calcutta`), so step
    /// 3 never indexes the modern name. Item 7's IST chip is labelled Kolkata
    /// and must therefore be typeable.
    @Test func kolkataIsTypeableEvenThoughTheTzDatabaseIndexesCalcuttaInstead() throws {
        #expect(TimeZoneDatabaseCityResolver.identifiersByCityName["kolkata"] == nil)
        let request = try #require(
            makeParser().parse("9am Kolkata to London", now: FixedDates.winterMidday).requestValue
        )
        #expect(request.sourceZone.timeZone.identifier == "Asia/Kolkata")
        #expect(request.sourceZone.matchSource == .offlineFallbackList)
    }

    @Test func portoResolvesThroughTheRealBundledFile() throws {
        let request = try #require(
            makeParser().parse("23:15 UK to Porto", now: FixedDates.winterMidday).requestValue
        )
        #expect(request.targetZone.timeZone.identifier == "Europe/Lisbon")
        #expect(request.targetZone.matchSource == .offlineFallbackList)
        // Display name comes from the resolved zone, not the typed token, so
        // the user can see Porto was treated as Lisbon time.
        #expect(request.targetZone.displayName == "Lisbon")
    }

    @Test func manchesterResolvesThroughTheRealBundledFile() throws {
        let request = try #require(
            makeParser().parse("23:15 manchester to japan", now: FixedDates.winterMidday)
                .requestValue
        )
        #expect(request.sourceZone.timeZone.identifier == "Europe/London")
        #expect(request.sourceZone.matchSource == .offlineFallbackList)
    }

    // MARK: Swappability

    /// The resolver takes its table by injection, which is what lets a larger
    /// gazetteer replace the file with no change to the chain.
    @Test func aReplacementTableNeedsNoCodeChanges() {
        let resolver = OfflineFallbackZoneResolver(identifiersByPlaceName: [
            "wakanda": ["Africa/Nairobi"],
        ])
        #expect(resolver.candidates(for: "wakanda").map(\.timeZoneIdentifier)
            == ["Africa/Nairobi"])
        #expect(resolver.candidates(for: "porto").isEmpty)
    }

    /// A file listing two zones for one name becomes an ordinary ambiguity.
    @Test func multipleIdentifiersForOnePlaceBecomeAPrompt() {
        let chain = ZoneResolverChain(resolvers: [
            OfflineFallbackZoneResolver(identifiersByPlaceName: [
                "springfield": ["America/Chicago", "America/New_York"],
            ]),
        ])
        guard case let .ambiguous(candidates) = chain.resolve("springfield") else {
            Issue.record("expected an ambiguity")
            return
        }
        #expect(candidates.count == 2)
    }

    /// A missing or unreadable file degrades to "no entries", never a crash.
    @Test func missingFileDecodesToAnEmptyTable() {
        #expect(OfflineFallbackGazetteer.decodeEntries(at: nil).isEmpty)
        #expect(OfflineFallbackGazetteer.decodeEntries(
            at: URL(fileURLWithPath: "/nonexistent/fallback-cities.json")
        ).isEmpty)
    }
}
