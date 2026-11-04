import Foundation

/// The pure parts of the saved-cities home-screen widget (item 36), shared
/// with the app so the two agree on the widget's identity and tested here
/// because the extension has no test target.
public enum SavedCitiesWidgetSupport {
    /// The widget's permanent identity — what WidgetKit stores for every
    /// placed widget and what the app passes to `reloadTimelines(ofKind:)`.
    /// Changing it orphans every widget already on a home screen.
    public static let kind = "dev.thisolivier.timeconverter.widgets.savedcities"

    /// The cells a widget draws (item 36b): the saved places in stored order,
    /// at most `WidgetLayoutPlan.maximumCities`. The local clock is left out —
    /// the home screen already shows one (Olivier, 2026-11-04).
    public static func cities(for display: WorldClockDisplay) -> [WorldClockRow] {
        Array(display.rows.filter { !$0.isLocal }.prefix(WidgetLayoutPlan.maximumCities))
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
