import Testing
import Foundation
@testable import TimeConverterCore

/// Item 37 — what the three-column grid calls each clock.
struct CompactPlaceNameTests {
    @Test func compactNamesDropWhatANarrowCellCannotHold() throws {
        let favourites = try ["Portland Oregon", "ET", "Tokyo", "St John's Antigua"].map {
            try #require(FavouriteDestination.resolvingTypedZone($0))
        }
        let display = WorldClock.readings(
            favourites: favourites, offset: 0, now: FixedDates.winterMidday, localZone: FixedZones.device
        )
        #expect(display.rows.map(\.placeName) == [
            "Los Angeles (local)", "Portland, Oregon", "ET (Eastern Time)", "Tokyo", "St John's, Antigua",
        ])
        #expect(display.rows.map(\.compactPlaceName) == [
            "Los Angeles", "Portland", "ET", "Tokyo", "St John's",
        ])
    }
}
