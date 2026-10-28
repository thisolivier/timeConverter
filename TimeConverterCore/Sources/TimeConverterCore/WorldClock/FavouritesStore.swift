import Foundation
import Observation

/// The starred destinations, in the order they were starred (item 30).
///
/// One JSON array under one key of an **injected** `UserDefaults`: the app
/// passes `.standard`, tests pass a throwaway suite, so no test ever touches
/// the real one. `@Observable`, so the star and the Clocks tab redraw when a
/// favourite is added or removed anywhere.
///
/// No reorder in the MVP (delete and re-star to move one); no iCloud sync.
@MainActor
@Observable
public final class FavouritesStore {
    /// Distinct from the DEBUG `-favourites` launch argument's key on purpose:
    /// launch arguments shadow `UserDefaults.standard`, so sharing a key would
    /// let the seed's raw string mask the stored array.
    public static let defaultsKey = "favouriteDestinations"

    public private(set) var favourites: [FavouriteDestination]

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        self.favourites = Self.load(from: defaults)
    }

    public func isFavourite(identifier: String, label: ZoneLabel) -> Bool {
        favourites.contains { $0.timeZoneIdentifier == identifier && $0.label == label }
    }

    public func isFavourite(_ destination: FavouriteDestination) -> Bool {
        isFavourite(identifier: destination.timeZoneIdentifier, label: destination.label)
    }

    /// Adds at the end, or removes if already starred.
    public func toggle(_ destination: FavouriteDestination) {
        if isFavourite(destination) {
            remove(destination)
        } else {
            favourites.append(destination)
            save()
        }
    }

    public func remove(_ destination: FavouriteDestination) {
        favourites.removeAll { $0 == destination }
        save()
    }

    /// Swipe-to-delete's shape. Hand-rolled because `remove(atOffsets:)` is a
    /// SwiftUI extension, and this package does not import SwiftUI.
    public func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where favourites.indices.contains(index) {
            favourites.remove(at: index)
        }
        save()
    }

    /// Replaces the whole list — the DEBUG `-favourites` seed's entry point.
    public func replaceAll(with destinations: [FavouriteDestination]) {
        favourites = destinations
        save()
    }

    // MARK: - Storage

    private func save() {
        guard let data = try? JSONEncoder().encode(favourites) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    /// Unreadable data degrades to no favourites rather than a crash.
    private static func load(from defaults: UserDefaults) -> [FavouriteDestination] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([FavouriteDestination].self, from: data)
        else { return [] }
        return decoded
    }
}
