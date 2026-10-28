import Testing
import Foundation
@testable import TimeConverterCore

/// Item 30's store. Every test gets its own throwaway `UserDefaults` suite,
/// removed afterwards, so the real defaults are never touched.
@MainActor
struct FavouritesStoreTests {
    let suiteName = "FavouritesStoreTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    static let london = FavouriteDestination(
        timeZoneIdentifier: "Europe/London", label: .place(name: "London", isDeviceLocal: false)
    )
    static let newYork = FavouriteDestination(
        timeZoneIdentifier: "America/New_York", label: .place(name: "New York", isDeviceLocal: false)
    )
    static let easternTime = FavouriteDestination(
        timeZoneIdentifier: "America/New_York", label: .abbreviation(code: "ET", expandedName: "Eastern Time")
    )

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    /// Swift Testing has no tearDown; each test calls this at the end.
    func removeSuite() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func startsEmpty() {
        defer { removeSuite() }
        #expect(FavouritesStore(defaults: defaults).favourites.isEmpty)
    }

    @Test func toggleAddsInInsertionOrderThenRemoves() {
        defer { removeSuite() }
        let store = FavouritesStore(defaults: defaults)
        store.toggle(Self.london)
        store.toggle(Self.newYork)
        #expect(store.favourites == [Self.london, Self.newYork])
        #expect(store.isFavourite(identifier: "Europe/London", label: .place(name: "London", isDeviceLocal: false)))
        store.toggle(Self.london)
        #expect(store.favourites == [Self.newYork])
        #expect(!store.isFavourite(Self.london))
    }

    /// The label is part of the identity: New York and ET are two favourites.
    @Test func sameZoneWithADifferentLabelIsASecondFavourite() {
        defer { removeSuite() }
        let store = FavouritesStore(defaults: defaults)
        store.toggle(Self.newYork)
        store.toggle(Self.easternTime)
        #expect(store.favourites.count == 2)
        #expect(Self.newYork.id != Self.easternTime.id)
        #expect(!store.isFavourite(identifier: "America/New_York", label: .place(name: "Toronto", isDeviceLocal: false)))
    }

    @Test func persistsAcrossInstances() {
        defer { removeSuite() }
        FavouritesStore(defaults: defaults).toggle(Self.easternTime)
        FavouritesStore(defaults: defaults).toggle(Self.london)
        #expect(FavouritesStore(defaults: defaults).favourites == [Self.easternTime, Self.london])
    }

    @Test func removeAndRemoveAtOffsets() {
        defer { removeSuite() }
        let store = FavouritesStore(defaults: defaults)
        store.replaceAll(with: [Self.london, Self.newYork, Self.easternTime])
        store.remove(Self.newYork)
        #expect(store.favourites == [Self.london, Self.easternTime])
        store.remove(atOffsets: IndexSet([0, 7]))
        #expect(store.favourites == [Self.easternTime])
        #expect(FavouritesStore(defaults: defaults).favourites == [Self.easternTime])
    }

    @Test func unreadableDataDegradesToNoFavourites() {
        defer { removeSuite() }
        defaults.set(Data("not json".utf8), forKey: FavouritesStore.defaultsKey)
        #expect(FavouritesStore(defaults: defaults).favourites.isEmpty)
    }

    @Test func zoneLabelRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode([Self.london, Self.easternTime])
        #expect(try JSONDecoder().decode([FavouriteDestination].self, from: data) == [Self.london, Self.easternTime])
    }
}
