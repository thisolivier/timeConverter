import Testing
import Foundation
@testable import TimeConverterCore

/// Item 36 — the pure parts of the saved-cities widget.
struct SavedCitiesWidgetSupportTests {
    @Test func entriesStartNowThenFallOnMinuteBoundaries() {
        let now = FixedDates.utc(year: 2026, month: 1, day: 15, hour: 23, minute: 42).addingTimeInterval(17)
        let dates = SavedCitiesWidgetSupport.entryDates(from: now, minutes: 3)
        #expect(dates.count == 4)
        #expect(dates[0] == now)
        #expect(dates[1] == FixedDates.utc(year: 2026, month: 1, day: 15, hour: 23, minute: 43))
        #expect(dates[2] == FixedDates.utc(year: 2026, month: 1, day: 15, hour: 23, minute: 44))
        #expect(dates[3] == FixedDates.utc(year: 2026, month: 1, day: 15, hour: 23, minute: 45))
    }

    @Test func theDefaultTimelineCoversAnHour() {
        let dates = SavedCitiesWidgetSupport.entryDates(from: FixedDates.winterMidday)
        #expect(dates.count == 61)
        #expect(dates.last! .timeIntervalSince(FixedDates.winterMidday) == 60 * 60)
    }

    @Test func citiesAreTheSavedPlacesWithoutLocalAtMostSix() throws {
        let favourites = ["London", "Tokyo", "ET", "Paris", "Sydney", "Mumbai", "Lima"]
            .compactMap(FavouriteDestination.resolvingTypedZone)
        #expect(favourites.count == 7)
        let display = WorldClock.readings(
            favourites: favourites, offset: 0, now: FixedDates.winterMidday, localZone: FixedZones.device
        )
        let cities = SavedCitiesWidgetSupport.cities(for: display)
        #expect(cities.count == 6)
        #expect(cities.allSatisfy { !$0.isLocal })
        #expect(cities.map(\.placeName) == ["London", "Tokyo", "ET (Eastern Time)", "Paris", "Sydney", "Mumbai"])
    }
}
