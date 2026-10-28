import SwiftUI
import TimeConverterCore

/// The iOS/iPadOS shell: one window holding the two tabs (item 31).
///
/// The app owns the one `FavouritesStore`, over the standard `UserDefaults`,
/// and hands it down through the environment: the star on the Convert tab and
/// the rows on the Clocks tab are two views of the same list.
///
/// It used to also start the Mac menu bar here — `MenuBarPresence` loaded a
/// macOS-SDK bundle out of `Contents/PlugIns` when the app was running under
/// Mac Catalyst (backlog item 12a). That is gone: the Mac is its own native
/// target now (`TimeConverterMac`), so this target is iOS-only and has nothing
/// platform-conditional left in it.
@main
struct TimeConverterApp: App {
    @State private var favouritesStore = Self.makeFavouritesStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(favouritesStore)
        }
    }

    /// The DEBUG `-favourites` seed replaces the stored list before anything
    /// draws, so a screenshot run starts from a known set. Ignored in Release.
    private static func makeFavouritesStore() -> FavouritesStore {
        let store = FavouritesStore(defaults: .standard)
        if let seededFavourites = LaunchArguments.seededFavourites {
            store.replaceAll(with: seededFavourites)
        }
        return store
    }
}
