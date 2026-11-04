import TimeConverterCore
import WidgetKit

/// Where the app's `FavouritesStore` copies its list for the home-screen
/// widget (item 36): into the shared keychain item the widget reads, then a
/// nudge to WidgetKit so the widget redraws now rather than at its next
/// scheduled refresh. The mirror is the only WidgetKit import in the app.
struct SavedCitiesWidgetMirror: FavouritesMirror {
    func publish(_ favourites: [FavouriteDestination]) {
        KeychainFavouritesMirror().publish(favourites)
        WidgetCenter.shared.reloadTimelines(ofKind: SavedCitiesWidgetSupport.kind)
    }
}
