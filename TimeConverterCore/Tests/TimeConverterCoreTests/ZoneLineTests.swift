import Testing
import Foundation
@testable import TimeConverterCore

/// Backlog item 21 — the line under the big time, and the header above it.
///
/// The whole item is one rule: **what the band says depends on how the target
/// token resolved**, not on the zone it resolved to. These tests are therefore
/// organised by resolution kind, one suite section per row of the matrix, and
/// every row names a real example rather than a synthetic zone.
struct ZoneLineTests {
    private let presenter = ConverterPresenter()

    private func display(for input: String, now: Date = FixedDates.winterMidday) throws
        -> ConverterDisplay {
        try #require(presenter.displayState(for: input, now: now).convertedDisplay)
    }

    // MARK: - The matrix

    /// Every resolution kind, with the header and sub-line it produces.
    ///
    /// Written as one table on purpose: the item is a *matrix*, and a reader
    /// checking that ET and São Paulo really do read differently should be able
    /// to see both rows at once.
    @Test(arguments: [
        // Target named as a tz-database city.
        (
            "8pm Lisbon in Sao Paulo",
            "In Sao Paulo",
            "Brasilia Standard Time (São Paulo)"
        ),
        // Target named as a city whose zone our tables curate two cities for.
        (
            "8pm Lisbon in New York",
            "In New York",
            "Eastern Time (New York, Toronto)"
        ),
        // Target named as a country with a canonical national clock.
        (
            "8am Lisbon in Japan",
            "In Tokyo",
            "Japan Standard Time (Tokyo)"
        ),
        // Target named as a country whose canonical zone is not its biggest
        // city's — Portugal is Lisbon, never Azores.
        (
            "8pm London in Portugal",
            "In Lisbon",
            "Western European Time (Lisbon)"
        ),
        // Target named through the offline fallback gazetteer: Porto has no
        // zone of its own, so the band honestly says Lisbon.
        (
            "8pm London in Porto",
            "In Lisbon",
            "Western European Time (Lisbon)"
        ),
        // Target named as a DST-neutral alias code.
        (
            "8pm Lisbon in ET",
            "In ET (Eastern Time)",
            "New York, Toronto"
        ),
        // Target named as a Foundation abbreviation.
        (
            "8pm Lisbon in PST",
            "In PST (Pacific Standard Time)",
            "Los Angeles, Vancouver"
        ),
        // Target named as a multi-word colloquial alias.
        (
            "8pm Lisbon in east coast",
            "In East Coast (Eastern Time)",
            "New York, Toronto"
        ),
    ])
    func eachResolutionKindGetsItsOwnHeaderAndSubLine(
        input: String,
        expectedHeader: String,
        expectedZoneLine: String
    ) throws {
        let display = try display(for: input)
        #expect(display.targetPlaceLabel == expectedHeader)
        #expect(display.targetZoneLine == expectedZoneLine)
    }

    /// The row the matrix above cannot hold, because it needs an injected
    /// device zone: a target nobody named.
    ///
    /// Folded into the place case rather than given a kind of its own — the
    /// device zone *is* a place — so it keeps item 14's `(local)` marker on the
    /// header and gains the ordinary place sub-line. The marker is the one
    /// thing here that must not be lost: an assumption the user cannot see is
    /// the single bug this app cannot afford.
    @Test func aDefaultedLocalTargetKeepsItsLocalMarkerAndGetsAZoneLine() throws {
        let state = presenter.displayState(
            for: "7pm London",
            now: FixedDates.winterMidday,
            localZone: FixedZones.losAngeles
        )
        let display = try #require(state.convertedDisplay)
        #expect(display.targetPlaceLabel == "In Los Angeles (local)")
        #expect(display.targetZoneLine == "Pacific Time (Los Angeles, Vancouver)")
    }

    /// An ambiguity resolved by *choosing* a code is still a code, so picking
    /// Chicago's meaning of CST reads as a code — while typing the city reads
    /// as a city. Same zone, two different sentences, which is the point.
    @Test func theCstChoiceReadsAsACodeAndTheCityReadsAsACity() throws {
        let chosenCode = try display(for: "9am London in CT")
        #expect(chosenCode.targetPlaceLabel == "In CT (Central Time)")
        #expect(chosenCode.targetZoneLine == "Chicago, Dallas")

        let typedCity = try display(for: "9am London in Chicago")
        #expect(typedCity.targetPlaceLabel == "In Chicago")
        #expect(typedCity.targetZoneLine == "Central Time (Chicago, Dallas)")
    }

    // MARK: - The zone name comes from Foundation

    /// What `TimeZone.localizedName(for: .generic)` actually returns, pinned.
    ///
    /// Asserted directly rather than only through the presenter because the
    /// choice of `.generic` over `.standard` is the one place item 21 trusts
    /// Foundation, and the names are not what you would guess: London is
    /// "United Kingdom Time" and not "Greenwich Mean Time", and São Paulo is
    /// "Brasilia Standard Time" and not the backlog's shorthand "Brasilia
    /// Time". If an OS update changes these, this test is the thing that says
    /// so, instead of eight presenter assertions failing at once.
    @Test(arguments: [
        ("America/Sao_Paulo", "Brasilia Standard Time"),
        ("Europe/London", "United Kingdom Time"),
        ("Asia/Tokyo", "Japan Standard Time"),
        ("America/New_York", "Eastern Time"),
        ("America/Los_Angeles", "Pacific Time"),
        ("Europe/Lisbon", "Western European Time"),
    ])
    func foundationsGenericZoneNamesAreWhatTheSubLineShows(
        identifier: String,
        expectedName: String
    ) throws {
        let timeZone = try #require(TimeZone(identifier: identifier))
        #expect(ZoneNameFormatting.genericName(for: timeZone) == expectedName)
    }

    /// `.standard` would have been the other obvious pick, and is wrong for
    /// exactly the reason the sub-line exists: it names today's offset rather
    /// than the zone, so a London conversion would read "Greenwich Mean Time"
    /// in July.
    @Test func standardNamesAreTheWrongChoiceAndThisRecordsWhy() throws {
        let london = try #require(TimeZone(identifier: "Europe/London"))
        #expect(london.localizedName(for: .standard, locale: ZoneNameFormatting.locale)
            == "Greenwich Mean Time")
        #expect(ZoneNameFormatting.genericName(for: london) == "United Kingdom Time")
    }

    /// The name must not drift with the device's region, because every other
    /// string in the app is hand-written English.
    @Test func theZoneNameIsPinnedToEnglishRatherThanTheDeviceLocale() throws {
        #expect(ZoneNameFormatting.locale == Locale(identifier: "en_US"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(tokyo.localizedName(for: .generic, locale: Locale(identifier: "fr_FR"))
            != ZoneNameFormatting.genericName(for: tokyo))
    }

    // MARK: - Representative cities

    /// The cities come from the abbreviation tables read backwards, so every
    /// zone those tables cover gets the hand-picked pair rather than one city
    /// scraped off the identifier.
    @Test(arguments: [
        ("America/New_York", ["New York", "Toronto"]),
        ("America/Chicago", ["Chicago", "Dallas"]),
        ("Europe/Paris", ["Paris", "Berlin"]),
        ("Asia/Kolkata", ["Kolkata", "Mumbai"]),
        ("Australia/Sydney", ["Sydney", "Melbourne"]),
        ("America/Sao_Paulo", ["São Paulo"]),
    ])
    func curatedZonesGetTheirCuratedCities(identifier: String, expectedCities: [String]) {
        #expect(ZoneRepresentativeCities.cities(forIdentifier: identifier) == expectedCities)
    }

    /// A zone no table mentions falls back to its own city, which is never
    /// wrong — just less interesting.
    @Test(arguments: [
        ("Europe/Berlin", ["Berlin"]),
        ("Asia/Kathmandu", ["Kathmandu"]),
        ("Africa/Nairobi", ["Nairobi"]),
    ])
    func uncuratedZonesFallBackToTheIdentifiersCity(
        identifier: String,
        expectedCities: [String]
    ) {
        #expect(ZoneRepresentativeCities.cities(forIdentifier: identifier) == expectedCities)
    }

    /// The self-consistency rule, which is the only non-obvious thing about
    /// the index: Foundation maps `MST` to Phoenix, but the curated cities for
    /// `MST` are Denver and Calgary — two cities that *do* observe daylight
    /// saving, unlike Phoenix. Labelling Phoenix with them would be a lie, so
    /// the entry is rejected and Phoenix keeps its own name. Same story for
    /// `AKST`, which Foundation maps to Juneau.
    @Test(arguments: [
        ("America/Phoenix", ["Phoenix"]),
        ("America/Juneau", ["Juneau"]),
    ])
    func zonesWhoseCuratedCitiesExcludeThemAreRejected(
        identifier: String,
        expectedCities: [String]
    ) {
        #expect(ZoneRepresentativeCities.cities(forIdentifier: identifier) == expectedCities)
        #expect(ZoneRepresentativeCities.curatedCitiesByIdentifier[identifier] == nil)
    }

    /// Diacritics must not break the rule: the tables spell `São Paulo`
    /// properly and the identifier can only ever yield `Sao Paulo`.
    @Test func theSelfConsistencyRuleFoldsDiacritics() {
        #expect(ZoneRepresentativeCities.isSelfConsistent(
            cities: ["São Paulo"], for: "America/Sao_Paulo"
        ))
        #expect(!ZoneRepresentativeCities.isSelfConsistent(
            cities: ["Denver", "Calgary"], for: "America/Phoenix"
        ))
    }

    /// The index is a static built from two dictionaries, so the one failure
    /// mode worth guarding is an unordered walk producing a different answer
    /// per run.
    @Test func theCityIndexIsDeterministic() {
        for identifier in ["Australia/Sydney", "America/New_York", "Europe/Lisbon"] {
            let firstReading = ZoneRepresentativeCities.cities(forIdentifier: identifier)
            for _ in 0..<20 {
                #expect(ZoneRepresentativeCities.cities(forIdentifier: identifier)
                    == firstReading)
            }
        }
    }

    /// Two is what the tables carry; three is the stated ceiling. Guarding the
    /// cap means a future table entry cannot quietly turn the parenthetical
    /// into a list.
    @Test func noZoneEverShowsMoreThanThreeCities() {
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            let cities = ZoneRepresentativeCities.cities(forIdentifier: identifier)
            #expect(!cities.isEmpty, Comment(rawValue: identifier))
            #expect(cities.count <= ZoneRepresentativeCities.maximumCityCount,
                    Comment(rawValue: identifier))
        }
    }

    // MARK: - What the line is not

    /// The headline change: no UTC offset anywhere in the result band or the
    /// box echo. Checked over a spread of inputs rather than one, because the
    /// offset used to be assembled in two different places.
    @Test(arguments: [
        "8pm Lisbon in Sao Paulo",
        "8pm Lisbon in ET",
        "11pm new york to tokyo",
        "12pm London to UTC",
    ])
    func theResultBandAndBoxEchoNoLongerMentionUTCOffsets(input: String) throws {
        let display = try display(for: input)
        // An *offset*, which is what left: `UTC` on its own is still a
        // perfectly good thing for a header to name, and `12pm London to UTC`
        // says so.
        for offsetPrefix in ["UTC+", "UTC-"] {
            #expect(!display.targetZoneLine.contains(offsetPrefix))
            #expect(!display.sourceEchoLine.contains(offsetPrefix))
            #expect(!display.targetPlaceLabel.contains(offsetPrefix))
        }
    }

    /// GMT and UTC are the datum, not a place, so their tables carry no cities
    /// — and under a header that already reads `IN UTC (COORDINATED UNIVERSAL
    /// TIME)` there is genuinely nothing left to add. The line goes empty and
    /// the view draws nothing, rather than printing an empty bracket.
    @Test(arguments: ["12pm London to UTC", "12pm London to GMT"])
    func theReferenceZonesHaveNoSubLineAtAll(input: String) throws {
        let display = try display(for: input)
        #expect(display.targetZoneLine.isEmpty)
        #expect(display.targetPlaceLabel.hasPrefix("In "))
    }

    /// …but a rollover still has to get through on its own when there is no
    /// zone detail to sit beside, rather than being swallowed with the offset.
    @Test func aRolloverSurvivesEvenWhenTheZoneDetailIsEmpty() throws {
        let display = try display(for: "1am Tokyo to UTC")
        #expect(display.targetZoneLine == "previous day")
    }

    // MARK: - The offsets that stay

    /// Chips keep their offsets: an offset is the entire basis for choosing
    /// between two meanings of `CST`, which is the one job it was ever doing.
    @Test func disambiguationChipsStillCarryTheirOffsets() throws {
        let chips = try #require(
            presenter.displayState(for: "9am CST in London", now: FixedDates.winterMidday)
                .problemChips
        )
        #expect(chips.map(\.label) == ["Chicago (UTC-6)", "Shanghai (UTC+8)"])
    }

    /// The Mac shell is unchanged this sprint and draws the one-sentence echo,
    /// which has nowhere else to put an offset — so `echoLine` keeps every one
    /// of them, deliberately disagreeing with the iOS slots.
    @Test func theMacEchoSentenceKeepsItsOffsets() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.echoLine
            == "8:00 pm Lisbon (UTC+1) → 4:00 pm Sao Paulo (UTC-3)")
    }

    /// And the footer sentence still carries no offsets: it was never about
    /// offsets, only about the difference between two of them. It gained a
    /// subject in item 20, which is a wording change and not an offset one.
    @Test func theFooterSentenceStillCarriesNoOffsets() throws {
        let display = try display(for: "8pm Lisbon in Sao Paulo", now: FixedDates.summerMidday)
        #expect(display.footerSentence == "Sao Paulo is 4 hours behind Lisbon.")
        #expect(!display.footerSentence.contains("UTC"))
    }

    // MARK: - Re-casing the typed code

    /// The tokenizer lowercases, so the code has to be put back into the case a
    /// person writes it in before it can be shown.
    @Test(arguments: [
        ("et", "ET"),
        ("pst", "PST"),
        ("east coast", "East Coast"),
        ("west coast", "West Coast"),
    ])
    func typedCodesAreRecasedForDisplay(token: String, expectedLabel: String) {
        #expect(ZoneTokenDisplay.label(forToken: token) == expectedLabel)
    }
}
