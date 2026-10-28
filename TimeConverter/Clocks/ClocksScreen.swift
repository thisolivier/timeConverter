import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The Clocks tab (item 31), the design-free MVP: a stock `List` on the
/// poster background, the local clock first, then one row per favourite
/// (swipe to delete), and the readout, day stepper and slider at the bottom.
///
/// Every string comes from `WorldClock.readings`. `TimelineView(.everyMinute)`
/// re-reads it each minute, so the rows tick at zero and the real time keeps
/// advancing underneath a non-zero offset. `TimeZone.current` is read here, as
/// `ContentView` does, so a zone change is picked up on the next tick.
struct ClocksScreen: View {
    @Environment(FavouritesStore.self) private var favouritesStore
    @State private var offset = ClockOffset(
        days: LaunchArguments.initialClockOffsetDays,
        launchMinutes: LaunchArguments.initialClockOffsetMinutes
    )

    static let emptyStateCopy = "Star a destination in Convert and its clock appears here."

    var body: some View {
        TimelineView(.everyMinute) { context in
            let display = WorldClock.readings(
                favourites: favouritesStore.favourites,
                offset: offset.interval,
                now: context.date,
                localZone: TimeZone.current
            )
            clockList(display)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ClockOffsetControls(
                        readout: display.readout,
                        offsetDescription: display.offsetDescription,
                        offset: $offset
                    )
                }
        }
        .background(PosterPalette.paper.ignoresSafeArea())
    }

    private func clockList(_ display: WorldClockDisplay) -> some View {
        let favouriteRows = Array(display.rows.dropFirst())
        return List {
            if let localRow = display.rows.first {
                WorldClockRowView(row: localRow)
                    .listRowBackground(PosterPalette.paper)
            }
            if favouriteRows.isEmpty {
                Text(Self.emptyStateCopy)
                    .font(PosterTypography.mono(size: 13, weight: .regular))
                    .foregroundStyle(PosterPalette.quietInk)
                    .listRowBackground(PosterPalette.paper)
            }
            ForEach(favouriteRows) { row in
                WorldClockRowView(row: row)
                    .listRowBackground(PosterPalette.paper)
            }
            .onDelete { offsets in
                for index in offsets {
                    if let favourite = favouriteRows[index].favourite {
                        favouritesStore.remove(favourite)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
