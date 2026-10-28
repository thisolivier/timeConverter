import Testing
import Foundation
@testable import TimeConverterCore

/// Item 25 — Antarctica as an input (spec amended 2026-10-28).
///
/// `antarctica` is a continent-as-country row with no national clock: P4, one
/// chip per research station with a distinct offset rule. A station typed by
/// name needs no table entry — step 3 already indexes the `Antarctica` area.
struct AntarcticaInputTests {
    private let parser = makeParser()

    private static let expectedStations = [
        "McMurdo", "Macquarie", "Casey", "Davis", "Mawson", "Syowa", "Troll", "Rothera",
    ]

    @Test func antarcticaIsAP4WithOneChipPerStation() throws {
        let prompt = try #require(parser.parse("3pm in Antarctica", now: FixedDates.winterMidday).promptValue)
        #expect(prompt.specIdentifier == "P4")
        #expect(prompt.side == .target)
        let choices = try #require(prompt.ambiguousChoices)
        #expect(choices.map(\.representativeCity) == Self.expectedStations)
        #expect(choices.allSatisfy { $0.timeZoneIdentifier.hasPrefix("Antarctica/") })
    }

    /// The row's whole point is to offer *different* clocks: no two stations
    /// may share an offset in both seasons, or one of them is a wasted chip.
    @Test func everyStationChipShowsADistinctClock() {
        let identifiers = CountryZoneTable.zonesByCountryName["antarctica"]?.candidateIdentifiers ?? []
        let offsetPairs = identifiers.map { identifier -> String in
            let zone = TimeZone(identifier: identifier)!
            return "\(zone.secondsFromGMT(for: FixedDates.winterMidday))/\(zone.secondsFromGMT(for: FixedDates.summerMidday))"
        }
        #expect(identifiers.count == 8)
        #expect(Set(offsetPairs).count == offsetPairs.count)
    }

    /// Stations resolve by name through the tz-database city resolver, and a
    /// chip's label is a token the chain reads back.
    @Test(arguments: [
        ("mcmurdo", "Antarctica/McMurdo"),
        ("south pole", "Antarctica/South_Pole"),
        ("vostok", "Antarctica/Vostok"),
        ("rothera", "Antarctica/Rothera"),
        ("troll", "Antarctica/Troll"),
    ])
    func stationNamesResolveThroughTheCityResolver(token: String, expectedIdentifier: String) throws {
        let resolution = ZoneResolverChain.standard.resolve(token)
        guard case let .resolved(resolvedZone) = resolution else {
            Issue.record("\(token) did not resolve: \(resolution)")
            return
        }
        #expect(resolvedZone.timeZone.identifier == expectedIdentifier)
        #expect(resolvedZone.matchSource == .timeZoneDatabaseCity)
    }

    @Test func mcmurdoConvertsEndToEnd() throws {
        // January is the southern summer: McMurdo runs New Zealand daylight time.
        let result = try #require(parser.parseAndConvert("3pm in McMurdo", now: FixedDates.winterMidday).resultValue)
        #expect(result.summary.hasSuffix("McMurdo (UTC+13) +1d"))
    }
}
