import SwiftUI
import TimeConverterCore
import WidgetKit

/// The saved-cities home-screen widget (backlog items 36 and 36b): the
/// saved places at a glance, in the converter's own digits, laid out by
/// `WidgetLayoutPlan` from the 2026-11-04 designs — small, medium and large,
/// the layout following the city count. Tapping anywhere opens the app.
///
/// ## Where the data comes from
///
/// `KeychainFavouritesMirror.read()` — the copy the app's `FavouritesStore`
/// publishes after every change (see that type for why it is the keychain for
/// now and an App Group later). The app also asks WidgetKit to reload this
/// kind whenever it publishes, so a newly starred place appears within a
/// moment rather than at the next scheduled refresh.
///
/// ## How it stays on time
///
/// A timeline of one entry per minute for the next hour, each pre-rendered
/// through `WorldClock.readings` at that minute, then `.atEnd` to build the
/// next hour. Entries cost nothing; it is reloads WidgetKit budgets.
struct SavedCitiesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SavedCitiesWidgetSupport.kind, provider: SavedCitiesTimelineProvider()) { entry in
            SavedCitiesWidgetView(entry: entry)
        }
        .configurationDisplayName("Saved cities")
        .description("Your starred places, on the clock.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SavedCitiesEntry: TimelineEntry {
    let date: Date
    let content: SavedCitiesWidgetContent
}

struct SavedCitiesTimelineProvider: TimelineProvider {
    /// What the gallery shows before the widget is placed, and what a
    /// user with no favourites would otherwise see as a lone local row.
    static let sampleFavourites: [FavouriteDestination] = [
        FavouriteDestination(timeZoneIdentifier: "Europe/London", label: .place(name: "London", isDeviceLocal: false)),
        FavouriteDestination(timeZoneIdentifier: "America/New_York", label: .abbreviation(code: "ET", expandedName: "Eastern Time")),
        FavouriteDestination(timeZoneIdentifier: "Asia/Tokyo", label: .place(name: "Tokyo", isDeviceLocal: false)),
    ]

    func placeholder(in context: Context) -> SavedCitiesEntry {
        Self.entry(at: .now, favourites: Self.sampleFavourites)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedCitiesEntry) -> Void) {
        let favourites = context.isPreview ? Self.sampleFavourites : KeychainFavouritesMirror.read()
        completion(Self.entry(at: .now, favourites: favourites))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedCitiesEntry>) -> Void) {
        let favourites = KeychainFavouritesMirror.read()
        let entries = SavedCitiesWidgetSupport.entryDates(from: .now).map { date in
            Self.entry(at: date, favourites: favourites)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// `TimeZone.current` is read here, as `ClocksScreen` reads it beside
    /// `context.date`: the extension is a process on the device, and this is
    /// the one place the device zone enters.
    static func entry(at date: Date, favourites: [FavouriteDestination]) -> SavedCitiesEntry {
        let display = WorldClock.readings(favourites: favourites, offset: 0, now: date, localZone: .current)
        return SavedCitiesEntry(
            date: date,
            content: SavedCitiesWidgetContent(
                cities: SavedCitiesWidgetSupport.cities(for: display),
                usesTwentyFourHourClock: Self.deviceUsesTwentyFourHourClock
            )
        )
    }

    /// The device's own clock setting, which the brief asks the widgets to
    /// follow (a 12-hour device gets a small `AM`/`PM`; a 24-hour one gets
    /// `20:38`). The app itself still speaks 12-hour everywhere.
    static var deviceUsesTwentyFourHourClock: Bool {
        switch Locale.current.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour: return true
        default: return false
        }
    }
}
