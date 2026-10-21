import Testing
import Foundation
@testable import TimeConverter

/// Item 13 — abbreviation inputs echo expanded (spec amendment 2026-10-21).
///
/// The rule is narrow on purpose: expansion happens *only* when the token
/// resolved through an abbreviation. Typing a city or a country must echo
/// exactly as it did before.
struct AbbreviationEchoTests {
    private let presenter = ConverterPresenter()

    private func echoLine(for input: String) -> String? {
        presenter.displayState(for: input, now: FixedDates.winterMidday)
            .convertedDisplay?.echoLine
    }

    // MARK: The spec amendment's own example

    @Test func easternTimeEchoesExpandedWithItsRepresentativeCities() {
        #expect(echoLine(for: "12pm ET in London")
            == "12:00 pm Eastern Time (New York, Toronto, UTC-5) → 5:00 pm London (UTC+0)")
    }

    /// Alias-table entries (step 1) and Foundation abbreviations (step 2) both
    /// expand, on either side of the sentence.
    @Test(arguments: [
        ("12pm PT in London", "Pacific Time (Los Angeles, Vancouver, UTC-8)"),
        ("12pm UK in Tokyo", "UK Time (London, UTC+0)"),
        ("12pm CET in Tokyo", "Central European Time (Paris, Berlin, UTC+1)"),
        ("12pm PST in London", "Pacific Standard Time (Los Angeles, Vancouver, UTC-8)"),
        ("12pm JST in London", "Japan Standard Time (Tokyo, UTC+9)"),
    ])
    func abbreviationsFromBothTablesExpand(input: String, expectedSourceDescription: String) throws {
        let line = try #require(echoLine(for: input))
        #expect(line.contains(expectedSourceDescription), Comment(rawValue: line))
    }

    @Test func anAbbreviationOnTheTargetSideExpandsToo() throws {
        let line = try #require(echoLine(for: "12pm London to ET"))
        #expect(line.hasSuffix("→ 7:00 am Eastern Time (New York, Toronto, UTC-5)"),
                Comment(rawValue: line))
    }

    /// GMT and UTC are the reference, not a place, so they carry no cities and
    /// the parenthetical is the offset alone.
    @Test func referenceZonesExpandWithoutCities() throws {
        let line = try #require(echoLine(for: "12pm GMT in Tokyo"))
        #expect(line.hasPrefix("12:00 pm Greenwich Mean Time (UTC+0)"), Comment(rawValue: line))
    }

    // MARK: Cities and countries are untouched

    @Test(arguments: [
        ("9:30 am New York to Lisbon", "9:30 am New York (UTC-5) → 2:30 pm Lisbon (UTC+0)"),
        ("23:15 Portugal to Japan", "11:15 pm Lisbon (UTC+0) → 8:15 am Tokyo (UTC+9) +1d"),
        // `porto` resolves through the offline gazetteer, which carries no
        // abbreviation metadata — it echoes as the zone actually used.
        ("23:15 London to Porto", "11:15 pm London (UTC+0) → 11:15 pm Lisbon (UTC+0)"),
    ])
    func cityAndCountryTokensEchoAsBefore(input: String, expectedLine: String) {
        #expect(echoLine(for: input) == expectedLine)
    }

    // MARK: The two meanings of CST get their own names

    /// Resolving the ambiguity by naming a city echoes the city, but resolving
    /// it by picking from the alias table's two entries must echo two different
    /// names — "Central Time" and "China Standard Time", never one vague label.
    @Test func cstsTwoMeaningsAreNamedSeparately() throws {
        let meanings = try #require(AliasZoneTable.meaningsByAlias["cst"])
        #expect(meanings.map(\.display.name) == ["Central Time", "China Standard Time"])
        #expect(meanings.map(\.display.representativeCities)
            == [["Chicago", "Dallas"], ["Shanghai", "Beijing"]])
    }

    // MARK: Table integrity

    /// At most two cities per entry, by design: a longer list stops being a
    /// hint and becomes a table.
    @Test func noEntryListsMoreThanTwoRepresentativeCities() {
        let aliasDisplays = AliasZoneTable.meaningsByAlias.values.flatMap { $0 }.map(\.display)
        let foundationDisplays = Array(
            FoundationAbbreviationDisplayTable.displaysByAbbreviation.values
        )
        for display in aliasDisplays + foundationDisplays {
            #expect(display.representativeCities.count <= 2, Comment(rawValue: display.name))
            #expect(!display.name.isEmpty)
        }
    }

    /// Every alias has a name, so no alias can echo as a bare identifier city.
    @Test func everyAliasEntryCarriesDisplayMetadata() {
        for (alias, meanings) in AliasZoneTable.meaningsByAlias {
            #expect(!meanings.isEmpty, Comment(rawValue: alias))
            for meaning in meanings {
                #expect(!meaning.display.name.isEmpty, Comment(rawValue: alias))
            }
        }
    }

    /// The Foundation table is deliberately partial. An abbreviation it does
    /// not cover must degrade to the old behaviour rather than to an empty name.
    @Test func anUncuratedFoundationAbbreviationFallsBackToItsCity() throws {
        let uncurated = TimeZone.abbreviationDictionary.keys.first {
            FoundationAbbreviationDisplayTable.displaysByAbbreviation[$0] == nil
                && TimeZone(identifier: TimeZone.abbreviationDictionary[$0]!) != nil
        }
        let abbreviation = try #require(uncurated)
        let candidates = FoundationAbbreviationZoneResolver().candidates(for: abbreviation)
        let candidate = try #require(candidates.first)
        #expect(candidate.abbreviationDisplay == nil)
        #expect(candidate.echoDisplayName == candidate.representativeCityName)
        #expect(candidate.echoRepresentativeCities.isEmpty)
    }

    /// The uppercase keys are what Foundation's dictionary uses; a lowercase
    /// key would silently never match.
    @Test func foundationTableKeysAreUppercaseAndKnownToFoundation() {
        for abbreviation in FoundationAbbreviationDisplayTable.displaysByAbbreviation.keys {
            #expect(abbreviation == abbreviation.uppercased())
            #expect(TimeZone.abbreviationDictionary[abbreviation] != nil,
                    "\(abbreviation) is not in Foundation's dictionary")
        }
    }

    /// The expanded name is for the echo only. Pickers and chips keep offering
    /// city names, because a chip label has to be typeable.
    @Test func disambiguationChoicesStillNameCitiesNotExpandedZones() throws {
        let prompt = try #require(
            makeParser().parse("9am CST in London", now: FixedDates.winterMidday).promptValue
        )
        #expect(prompt.ambiguousChoices?.map(\.representativeCity) == ["Chicago", "Shanghai"])
    }
}
