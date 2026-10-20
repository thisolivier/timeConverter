import Testing
import Foundation
@testable import TimeConvertor

/// The five-step resolution chain: which resolver answers, and what happens
/// when more than one meaning comes back.
struct ZoneResolverChainTests {
    private let chain = ZoneResolverChain.standard

    @Test func chainHasTheFiveSpecifiedResolversInOrder() {
        let sources = chain.resolvers.map(\.matchSource)
        #expect(sources == [
            .aliasTable,
            .foundationAbbreviation,
            .timeZoneDatabaseCity,
            .countryTable,
            .offlineFallbackList,
        ])
    }

    /// One token per step, proving each step is reachable and that earlier
    /// steps shadow later ones.
    @Test(arguments: [
        ("et", "America/New_York", ZoneMatchSource.aliasTable),
        ("pt", "America/Los_Angeles", ZoneMatchSource.aliasTable),
        ("uk", "Europe/London", ZoneMatchSource.aliasTable),
        ("cet", "Europe/Paris", ZoneMatchSource.aliasTable),
        ("pst", "America/Los_Angeles", ZoneMatchSource.foundationAbbreviation),
        ("gmt", "GMT", ZoneMatchSource.foundationAbbreviation),
        ("london", "Europe/London", ZoneMatchSource.timeZoneDatabaseCity),
        ("new york", "America/New_York", ZoneMatchSource.timeZoneDatabaseCity),
        ("lisbon", "Europe/Lisbon", ZoneMatchSource.timeZoneDatabaseCity),
        ("japan", "Asia/Tokyo", ZoneMatchSource.countryTable),
        ("france", "Europe/Paris", ZoneMatchSource.countryTable),
        ("germany", "Europe/Berlin", ZoneMatchSource.countryTable),
        ("south africa", "Africa/Johannesburg", ZoneMatchSource.countryTable),
        ("portugal", "Europe/Lisbon", ZoneMatchSource.countryTable),
        ("spain", "Europe/Madrid", ZoneMatchSource.countryTable),
        ("porto", "Europe/Lisbon", ZoneMatchSource.offlineFallbackList),
        ("manchester", "Europe/London", ZoneMatchSource.offlineFallbackList),
    ])
    func tokensResolveViaTheExpectedStep(
        token: String,
        expectedIdentifier: String,
        expectedSource: ZoneMatchSource
    ) throws {
        guard case let .resolved(zone) = chain.resolve(token) else {
            Issue.record("expected \(token) to resolve")
            return
        }
        #expect(zone.timeZone.identifier == expectedIdentifier)
        #expect(zone.matchSource == expectedSource)
        #expect(zone.originalToken == token)
    }

    /// Case-insensitivity is handled by normalisation, so the chain only ever
    /// sees lowercase — but the alias and country tables must be lowercase too.
    @Test func everyTableKeyIsLowercase() {
        for key in AliasZoneTable.identifiersByAlias.keys {
            #expect(key == key.lowercased(), "alias key '\(key)' is not lowercase")
        }
        for key in CountryZoneTable.zonesByCountryName.keys {
            #expect(key == key.lowercased(), "country key '\(key)' is not lowercase")
        }
    }

    // MARK: Step-3 guard — legacy identifiers are not cities

    /// Country handling belongs to step 4. If the OS's known-identifier list
    /// carries legacy backward names, the city index must not pick them up, or
    /// `portugal` would resolve here and skip the canonical-zone policy.
    @Test(arguments: ["portugal", "japan", "gb", "eire", "turkey", "egypt",
                      "iceland", "poland", "israel", "cuba", "iran", "libya",
                      "prc", "roc", "rok", "nz", "hongkong", "uct",
                      "universal", "zulu"])
    func legacyCountryAndAliasIdentifiersAreNotIndexedAsCities(token: String) {
        #expect(TimeZoneDatabaseCityResolver.identifiersByCityName[token] == nil)
    }

    /// A few country names *are* canonical tz identifiers in their own right —
    /// `America/Jamaica`, `Asia/Singapore`. Those resolve at step 3, which is
    /// fine: the country table names the same zone, so there is no policy to
    /// bypass. The guard is only about legacy aliases.
    @Test(arguments: [
        ("jamaica", "America/Jamaica"),
        ("singapore", "Asia/Singapore"),
    ])
    func countryNamesThatAreGenuineTzCitiesResolveAtStepThree(
        token: String,
        expectedIdentifier: String
    ) throws {
        guard case let .resolved(zone) = chain.resolve(token) else {
            Issue.record("expected \(token) to resolve")
            return
        }
        #expect(zone.timeZone.identifier == expectedIdentifier)
        #expect(zone.matchSource == .timeZoneDatabaseCity)
        // The country table agrees, so step 3 winning changes nothing.
        #expect(CountryZoneTable.zonesByCountryName[token]?.candidateIdentifiers
            == [expectedIdentifier])
    }

    /// Region-prefixed legacy aliases (`US/Pacific`, `Canada/Eastern`,
    /// `Etc/GMT+5`) must not contribute city names either.
    @Test func onlyRealAreaPrefixedIdentifiersAreIndexed() {
        #expect(TimeZoneDatabaseCityResolver.isCityBearing("Europe/London"))
        #expect(TimeZoneDatabaseCityResolver.isCityBearing("America/Argentina/Buenos_Aires"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("Portugal"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("Japan"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("GB"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("US/Pacific"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("Canada/Eastern"))
        #expect(!TimeZoneDatabaseCityResolver.isCityBearing("Etc/GMT+5"))

        for identifier in TimeZoneDatabaseCityResolver.identifiersByCityName.values.flatMap({ $0 }) {
            #expect(identifier.contains("/"), "\(identifier) was indexed without an area")
        }
    }

    // MARK: Ambiguity — always prompt, never default

    /// Foundation resolves CST to Chicago on its own; the alias table overrides
    /// that so the user is asked rather than guessed at.
    @Test func cstIsAmbiguous() throws {
        guard case let .ambiguous(candidates) = chain.resolve("cst") else {
            Issue.record("expected cst to be ambiguous")
            return
        }
        #expect(candidates.map(\.timeZoneIdentifier) == ["America/Chicago", "Asia/Shanghai"])
        #expect(candidates.allSatisfy { $0.matchSource == .aliasTable })
    }

    @Test func istIsAmbiguous() throws {
        guard case let .ambiguous(candidates) = chain.resolve("ist") else {
            Issue.record("expected ist to be ambiguous")
            return
        }
        #expect(candidates.map(\.timeZoneIdentifier) == ["Asia/Kolkata", "Europe/Dublin"])
    }

    // MARK: Countries — canonical clock resolves, no-clock prompts

    /// Portugal spans two zones but has a national clock, so it resolves
    /// straight to Lisbon rather than offering the Azores.
    @Test(arguments: [
        ("portugal", "Europe/Lisbon"),
        ("spain", "Europe/Madrid"),
        ("chile", "America/Santiago"),
        ("indonesia", "Asia/Jakarta"),
        ("new zealand", "Pacific/Auckland"),
        ("argentina", "America/Argentina/Buenos_Aires"),
    ])
    func countriesWithANationalClockResolveToIt(
        country: String,
        expectedIdentifier: String
    ) throws {
        guard case let .resolved(zone) = chain.resolve(country) else {
            Issue.record("expected \(country) to resolve to a single zone")
            return
        }
        #expect(zone.timeZone.identifier == expectedIdentifier)
        #expect(zone.matchSource == .countryTable)
    }

    @Test func usaReturnsTheSixPrimaryZones() throws {
        guard case let .ambiguous(candidates) = chain.resolve("usa") else {
            Issue.record("expected usa to be ambiguous")
            return
        }
        #expect(candidates.map(\.timeZoneIdentifier) == [
            "America/New_York", "America/Chicago", "America/Denver",
            "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu",
        ])
    }

    /// The spec's full no-national-clock list.
    @Test(arguments: ["australia", "brazil", "canada", "russia", "mexico"])
    func countriesWithoutANationalClockPrompt(country: String) {
        guard case let .ambiguous(candidates) = chain.resolve(country) else {
            Issue.record("expected \(country) to be ambiguous")
            return
        }
        #expect(candidates.count > 1)
    }

    /// Every entry is one or the other — a canonical entry must never leak more
    /// than one candidate, and a no-clock entry must never collapse to one.
    @Test func everyCountryEntryIsEitherCanonicalOrMultiCandidate() {
        for (country, zones) in CountryZoneTable.zonesByCountryName {
            switch zones {
            case .canonical:
                #expect(zones.candidateIdentifiers.count == 1, "\(country)")
            case .noCanonicalClock:
                #expect(zones.candidateIdentifiers.count > 1, "\(country)")
            }
        }
    }

    // MARK: Unknown tokens

    @Test(arguments: ["narnia", "zzz", "atlantis", ""])
    func unrecognisedTokensAreUnknown(token: String) {
        #expect(chain.resolve(token) == .unknown)
    }

    // MARK: Table integrity

    @Test func everyTableIdentifierIsAValidTimeZone() {
        let allIdentifiers = AliasZoneTable.identifiersByAlias.values.flatMap { $0 }
            + CountryZoneTable.zonesByCountryName.values.flatMap(\.candidateIdentifiers)
            + OfflineFallbackGazetteer.bundledEntries.values.flatMap { $0 }
        for identifier in allIdentifiers {
            #expect(TimeZone(identifier: identifier) != nil, "invalid identifier \(identifier)")
        }
    }
}
