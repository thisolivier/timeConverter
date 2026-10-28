import Testing
import Foundation
@testable import TimeConverterCore

/// Item 26 — the grown offline gazetteer (spec amended 2026-10-28).
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

    /// Names shared by places in different zones list both, so they prompt.
    @Test(arguments: ["san jose", "washington"])
    func splitNamesPrompt(token: String) throws {
        let prompt = try #require(parser.parse("9am in \(token)", now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.ambiguousChoices?.count == 2)
    }

    /// The suggester reads the gazetteer's vocabulary, so the new cities are
    /// offered for their own typos — and the larger vocabulary still leaves
    /// the original typo rows (`ZoneSuggestionEngineTests`) untouched.
    @Test(arguments: [("barcelna", "barcelona"), ("mumbia", "mumbai"), ("shenzen", "shenzhen")])
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
        #expect(entries.count > 250)
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
