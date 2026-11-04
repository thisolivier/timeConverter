import Foundation

/// The pure parts of the saved-cities home-screen widget (item 36), shared
/// with the app so the two agree on the widget's identity and tested here
/// because the extension has no test target.
public enum SavedCitiesWidgetSupport {
    /// The widget's permanent identity — what WidgetKit stores for every
    /// placed widget and what the app passes to `reloadTimelines(ofKind:)`.
    /// Changing it orphans every widget already on a home screen.
    public static let kind = "dev.thisolivier.timeconverter.widgets.savedcities"

    /// The large widget shows the local row and this many favourites; the
    /// rest are in the app. Five fills a large widget at the row height the
    /// view uses without clipping on the smallest iPhone.
    public static let maximumFavouriteRows = 5

    /// The rows a widget draws: local first, then favourites in stored order,
    /// capped.
    public static func rows(for display: WorldClockDisplay) -> [WorldClockRow] {
        Array(display.rows.prefix(1 + maximumFavouriteRows))
    }

    /// When the timeline's entries fall: `now` itself, then every minute
    /// boundary for the next `minutes` minutes, so the digits change on the
    /// minute like the app's `TimelineView(.everyMinute)`. Entries are free;
    /// reloads are budgeted, which is why the timeline carries an hour of
    /// them and asks to be rebuilt only at its end.
    public static func entryDates(from now: Date, minutes: Int = 60) -> [Date] {
        let secondsSinceReference = now.timeIntervalSinceReferenceDate
        let nextBoundary = (secondsSinceReference / 60).rounded(.down) * 60 + 60
        let boundaries = (0..<minutes).map { minute in
            Date(timeIntervalSinceReferenceDate: nextBoundary + Double(minute) * 60)
        }
        return [now] + boundaries
    }
}
