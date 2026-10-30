import Testing
import Foundation
@testable import TimeConverterCore

/// Item 26 — the grown offline gazetteer (spec amended 2026-10-28), grown
/// again for item 34 (2026-10-30) to regional capitals and comparable places.
///
/// The file is editorial data, so these tests pin a sample of real cities to
/// their zones and check the whole file's integrity: every identifier is a real
/// zone, every name is reachable (no earlier chain step shadows it), and names
/// follow the file's lowercase convention.
struct GazetteerCoverageTests {
    private let parser = makeParser()
    private let entries = OfflineFallbackGazetteer.bundledEntries

    @Test(arguments: [
        ("barcelona", "Europe/Madrid"),
        ("mumbai", "Asia/Kolkata"),
        ("delhi", "Asia/Kolkata"),
        ("rio", "America/Sao_Paulo"),
        ("rio de janeiro", "America/Sao_Paulo"),
        ("beijing", "Asia/Shanghai"),
        ("osaka", "Asia/Tokyo"),
        ("munich", "Europe/Berlin"),
        ("milan", "Europe/Rome"),
        ("san francisco", "America/Los_Angeles"),
        ("houston", "America/Chicago"),
        ("calgary", "America/Edmonton"),
        ("abuja", "Africa/Lagos"),
        ("wellington", "Pacific/Auckland"),
        ("canberra", "Australia/Sydney"),
        ("quito", "America/Guayaquil"),
        ("salvador", "America/Bahia"),
        ("washington dc", "America/New_York"),
        // Item 34 — regional capitals and places of comparable notoriety.
        ("montgomery", "America/Chicago"),
        ("sacramento", "America/Los_Angeles"),
        ("portland oregon", "America/Los_Angeles"),
        ("fredericton", "America/Moncton"),
        ("oaxaca", "America/Mexico_City"),
        ("florianopolis", "America/Sao_Paulo"),
        ("sheffield", "Europe/London"),
        ("galway", "Europe/Dublin"),
        ("salzburg", "Europe/Vienna"),
        ("wiesbaden", "Europe/Berlin"),
        ("bavaria", "Europe/Berlin"),
        ("tenerife", "Atlantic/Canary"),
        ("svalbard", "Arctic/Longyearbyen"),
        ("kazan", "Europe/Moscow"),
        ("tyumen", "Asia/Yekaterinburg"),
        ("thiruvananthapuram", "Asia/Kolkata"),
        ("kerala", "Asia/Kolkata"),
        ("hohhot", "Asia/Shanghai"),
        ("okinawa", "Asia/Tokyo"),
        ("cairns", "Australia/Brisbane"),
        ("queensland", "Australia/Brisbane"),
        ("dunedin", "Pacific/Auckland"),
        ("bora bora", "Pacific/Tahiti"),
        ("texas", "America/Chicago"),
        ("dc", "America/New_York"),
    ])
    func sampleCitiesResolveToTheirZone(token: String, expectedIdentifier: String) throws {
        guard case let .resolved(resolvedZone) = ZoneResolverChain.standard.resolve(token) else {
            Issue.record("\(token) did not resolve to a single zone")
            return
        }
        #expect(resolvedZone.timeZone.identifier == expectedIdentifier)
        #expect(resolvedZone.matchSource == .offlineFallbackList)
    }

    /// The two QA reports that motivated the item, end to end.
    @Test func theReportedInputsNowConvert() throws {
        let barcelona = try #require(parser.parse("3pm in Barcelona", now: FixedDates.winterMidday).requestValue)
        #expect(barcelona.targetZone.timeZone.identifier == "Europe/Madrid")
        let mumbai = try #require(parser.parse("10am Mumbai in London", now: FixedDates.winterMidday).requestValue)
        #expect(mumbai.sourceZone.timeZone.identifier == "Asia/Kolkata")
    }

    /// Names shared by notable places in different zones list every zone, so
    /// they prompt — Portland (Oregon, Maine) is item 34's motivating case.
    @Test(arguments: [
        ("san jose", 2), ("washington", 2), ("portland", 2), ("cambridge", 2), ("newcastle", 2),
        ("valencia", 2), ("springfield", 3), ("hamilton", 3), ("victoria", 3), ("santa cruz", 3),
    ])
    func splitNamesPrompt(token: String, expectedChoiceCount: Int) throws {
        let prompt = try #require(parser.parse("9am in \(token)", now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.ambiguousChoices?.count == expectedChoiceCount)
    }

    /// A split name never lists the same zone twice, and never lists two zones
    /// that merely share a clock — a prompt between identical offsets would be
    /// a question with no answer.
    @Test func splitNamesOfferDistinctClocks() {
        for (name, identifiers) in entries where identifiers.count > 1 {
            let offsets = identifiers.compactMap { TimeZone(identifier: $0) }.map {
                [$0.secondsFromGMT(for: FixedDates.winterMidday), $0.secondsFromGMT(for: FixedDates.summerMidday)]
            }
            #expect(Set(offsets.map { "\($0)" }).count == identifiers.count, Comment(rawValue: name))
        }
    }

    /// The suggester reads the gazetteer's vocabulary, so the new cities are
    /// offered for their own typos — and the larger vocabulary still leaves
    /// the original typo rows (`ZoneSuggestionEngineTests`) untouched.
    @Test(arguments: [
        ("barcelna", "barcelona"), ("mumbia", "mumbai"), ("shenzen", "shenzhen"),
        ("portlnd", "portland"), ("salzberg", "salzburg"),
    ])
    func newCitiesAreOfferedForTheirTypos(typo: String, expected: String) {
        let offered = ZoneSuggestionEngine.suggestions(for: typo, in: .standard).map(\.token)
        #expect(offered.first == expected)
    }

    /// The abbreviation guard still holds: a code-shaped typo never gets a city
    /// it merely sits near (`cst` stays empty, as before the growth).
    @Test func codeTyposDoNotPickUpNewCities() {
        let offered = ZoneSuggestionEngine.suggestions(for: "cst", in: .standard).map(\.token)
        #expect(offered.isEmpty)
    }

    @Test func everyIdentifierIsARealTimeZone() {
        #expect(entries.count > 3000)
        for (name, identifiers) in entries {
            #expect(!identifiers.isEmpty, Comment(rawValue: name))
            for identifier in identifiers {
                #expect(TimeZone(identifier: identifier) != nil, Comment(rawValue: "\(name) → \(identifier)"))
            }
        }
    }

    /// A name an earlier step already answers could never be reached, so it
    /// would be dead data that only looks like coverage.
    @Test func noEntryIsShadowedByAnEarlierStep() {
        let earlierSteps = ZoneResolverChain.standard.resolvers.filter {
            $0.matchSource != .offlineFallbackList
        }
        for name in entries.keys {
            let shadowingStep = earlierSteps.first { !$0.candidates(for: name).isEmpty }
            #expect(shadowingStep == nil, Comment(rawValue: "\(name) is shadowed by \(String(describing: shadowingStep?.matchSource))"))
        }
    }

    @Test func namesAreLowercaseAndTrimmed() {
        for name in entries.keys {
            #expect(name == name.lowercased())
            #expect(name == name.trimmingCharacters(in: .whitespaces))
            #expect(!name.contains("  "))
        }
    }
}
