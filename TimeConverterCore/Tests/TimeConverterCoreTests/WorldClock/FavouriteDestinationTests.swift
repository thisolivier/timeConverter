import Testing
import Foundation
@testable import TimeConverterCore

/// What the star stores (item 31's hook into item 30).
struct FavouriteDestinationTests {
    let presenter = ConverterPresenter()

    @Test func aPlaceTargetIsFavouritableWithItsPlaceLabel() {
        let display = presenter.displayState(for: "12pm ET in London", now: FixedDates.winterMidday).convertedDisplay
        #expect(display?.favouritableTarget == FavouriteDestination(
            timeZoneIdentifier: "Europe/London", label: .place(name: "London", isDeviceLocal: false)
        ))
    }

    @Test func aCodeTargetKeepsTheCodeAndItsExpansion() {
        let display = presenter.displayState(for: "9am London in ET", now: FixedDates.winterMidday).convertedDisplay
        #expect(display?.favouritableTarget == FavouriteDestination(
            timeZoneIdentifier: "America/New_York", label: .abbreviation(code: "ET", expandedName: "Eastern Time")
        ))
    }

    /// `7pm East Coast` defaults the target to the device zone: no star.
    @Test func aLocalTargetCannotBeStarred() {
        let display = presenter.displayState(for: "7pm East Coast", now: FixedDates.winterMidday).convertedDisplay
        #expect(display != nil)
        #expect(display?.favouritableTarget == nil)
    }

    @Test func resolvingATypedZoneMatchesWhatTheStarStores() {
        #expect(FavouriteDestination.resolvingTypedZone("Portugal") == FavouriteDestination(
            timeZoneIdentifier: "Europe/Lisbon", label: .place(name: "Lisbon", isDeviceLocal: false)
        ))
        #expect(FavouriteDestination.resolvingTypedZone("CST") == nil, "ambiguous zones are skipped")
        #expect(FavouriteDestination.resolvingTypedZone("Lodnon") == nil, "unknown zones are skipped")
    }

    /// The zone line under a code favourite must be the curated cities the
    /// result band showed, which means rebuilding them from the label.
    @Test func aCodeFavouriteRecoversItsCuratedCities() throws {
        let chicago = FavouriteDestination(
            timeZoneIdentifier: "America/Chicago", label: .abbreviation(code: "CST", expandedName: "Central Time")
        )
        let zone = try #require(chicago.resolvedZone)
        #expect(zone.representativeCities == ["Chicago", "Dallas"])
        #expect(zone.zoneLabel == chicago.label)
    }

    @Test func anUnknownIdentifierHasNoZone() {
        let stale = FavouriteDestination(
            timeZoneIdentifier: "Mars/Olympus_Mons", label: .place(name: "Olympus Mons", isDeviceLocal: false)
        )
        #expect(stale.resolvedZone == nil)
    }
}
