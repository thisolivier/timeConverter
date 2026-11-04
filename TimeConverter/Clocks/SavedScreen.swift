import SwiftUI
import TimeConverterCore
import TimeConverterUI

/// The Saved tab (item 31 as Clocks; item 37 brings the 2026-11-04 design):
/// the local clock and every saved place as a grid whose shape follows the
/// count — one column up to three clocks, two up to eight, three beyond —
/// with the readout and the endless dial at the bottom, and a floating `+`
/// for adding a place by name.
///
/// Every string comes from `WorldClock.readings`; the column decision is
/// `SavedGridLayout` in the core, so Android lays out identically.
/// `TimelineView(.everyMinute)` re-reads the clock each minute, so the cells
/// tick at zero and the real time keeps advancing under a non-zero offset.
/// `TimeZone.current` is read here, as `ContentView` does.
///
/// Tapping a saved cell asks before removing it (the design shows no
/// affordance on the cell itself, and a grid has no swipe-to-delete). The
/// local cell is inert.
struct SavedScreen: View {
    @Environment(FavouritesStore.self) private var favouritesStore
    @State private var offset = ClockOffset(
        launchDays: LaunchArguments.initialClockOffsetDays,
        launchMinutes: LaunchArguments.initialClockOffsetMinutes
    )
    @State private var favouriteToRemove: FavouriteDestination?
    @State private var isAddingAPlace = LaunchArguments.addPlaceInput != nil

    static let emptyStateCopy = "Tap + to save a place, or star a result in Convert."

    var body: some View {
        TimelineView(.everyMinute) { context in
            let display = WorldClock.readings(
                favourites: favouritesStore.favourites,
                offset: offset.interval,
                now: context.date,
                localZone: TimeZone.current
            )
            clockGrid(display)
                .overlay(alignment: .bottomTrailing) { addButton }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ClockOffsetControls(
                        readout: display.readout,
                        offsetDescription: display.offsetDescription,
                        offset: $offset
                    )
                }
        }
        .background(PosterPalette.paper.ignoresSafeArea())
        .confirmationDialog(
            removalTitle,
            isPresented: Binding(
                get: { favouriteToRemove != nil },
                set: { if !$0 { favouriteToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let favourite = favouriteToRemove { favouritesStore.remove(favourite) }
                favouriteToRemove = nil
            }
            Button("Cancel", role: .cancel) { favouriteToRemove = nil }
        }
        .sheet(isPresented: $isAddingAPlace) {
            AddSavedPlaceSheet(initialText: LaunchArguments.addPlaceInput ?? "")
                .environment(favouritesStore)
        }
    }

    private var removalTitle: String {
        guard let favourite = favouriteToRemove else { return "" }
        return "Remove \(favourite.label.placeNameDescription) from Saved?"
    }

    // MARK: - The grid

    private func clockGrid(_ display: WorldClockDisplay) -> some View {
        let columnCount = SavedGridLayout.columnCount(forClockCount: display.rows.count)
        let density = SavedCellDensity(columnCount: columnCount)
        let rows = SavedGridLayout.rows(display.rows, columnCount: columnCount)
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    if rowIndex > 0 { SavedGridHairline() }
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.element.id) { cellIndex, clock in
                            if cellIndex > 0 { SavedGridHairline(vertical: true) }
                            cell(clock, density: density)
                        }
                        // A short last row keeps its cells at column width.
                        ForEach(row.count..<columnCount, id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                if display.rows.count == 1 {
                    Text(Self.emptyStateCopy)
                        .font(PosterTypography.mono(size: 13, weight: .regular))
                        .foregroundStyle(PosterPalette.quietInk)
                        .padding(.horizontal, density.horizontalPadding)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 12)
            // Room for the floating button under the last row.
            .padding(.bottom, 72)
        }
    }

    private func cell(_ clock: WorldClockRow, density: SavedCellDensity) -> some View {
        SavedClockCell(clock: clock, density: density)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let favourite = clock.favourite else { return }
                favouriteToRemove = favourite
            }
            .accessibilityAddTraits(clock.isLocal ? [] : .isButton)
            .accessibilityHint(clock.isLocal ? "" : "Removes this place from Saved")
    }

    // MARK: - Add

    private var addButton: some View {
        Button {
            isAddingAPlace = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PosterPalette.accent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.regularMaterial))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Add a place")
    }
}

/// The hairlines between cells, in the design's brown: ink at 60%.
struct SavedGridHairline: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(PosterPalette.ink.opacity(0.6))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}
