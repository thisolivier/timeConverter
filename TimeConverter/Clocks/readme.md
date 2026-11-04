# Clocks → the Saved tab

The Saved tab (backlog item 31 as "Clocks", item 37 brings the 2026-11-04
design — `docs/design/` plus the `widgets and saved` set): the local clock and
every saved place as a grid, the readout and the endless dial at the bottom,
a floating `+` for adding a place by name. The folder keeps its old name; the
tab says **Saved** with the clock icon.

## Working patterns

- **Logic-free views.** Every string comes from `WorldClock.readings` in
  `TimeConverterCore` (see its `WorldClock/readme.md`); the cells are the
  converter's own digits and offset phrases, with day markers against the
  real local today.
- **The layout follows the count** (item 37): `SavedGridLayout` in the core
  decides — one column up to three clocks (local included), two up to eight,
  three from nine, where the caption is the short offset phrase (`8h behind`)
  and the label the compact name (`Portland`, `ET`, no `(local)`). The view
  owns the point sizes (`SavedCellDensity`): every cell in a layout shares
  one numeral size, so clocks read as one row of type; a numeral that still
  will not fit its column scales down alone, as on the result band.
- **Hairlines, not boxes**: 1pt ink-at-60% lines between rows and between
  columns; a short last row keeps its cells at column width.
- **Tap a saved cell to remove it**, through a confirmation (`Remove Tokyo
  from Saved?` — Cancel / Remove). The design shows no affordance on the
  cell and a grid has no swipe-to-delete; the local cell is inert.
- **`+` opens `AddSavedPlaceSheet`**, which is the Convert tab's own
  resolution and not a lookalike: the same `ConverterDisplayDriver`, so a bare
  place converts (item 22), an ambiguous one prompts with the same chips, a
  misspelt one gets the same did-you-mean. What the star would store is what
  `Add` saves; `Already saved` when it is.
- **Live to the minute.** `TimelineView(.everyMinute)` re-reads the clock, so
  cells tick at zero and the real time keeps advancing under a non-zero
  offset. `TimeZone.current` is read here, beside `context.date`.
- **An endless dial, not a slider** (`ClockOffset`, unit-tested in
  `TimeConverterTests`). A full-width swipe is 12 hours, pulling left is
  forwards; swipes accumulate, 15-minute snapping, tap resets.
- **Persistence** is the app-owned `FavouritesStore` on `UserDefaults.standard`,
  from the environment, mirrored out for the home-screen widget
  (`SavedCitiesWidgetMirror`). No reorder yet.
- **QA hooks** (DEBUG): `-favourites`, `-selectedTab saved`,
  `-clockOffsetMinutes`, and `-addPlace "Portland"` to open the sheet with
  text typed. The stress-test set used for item 37 (empty → twenty clocks,
  long names, the sheet's three states, dark) is scripted in the session
  notes and worth re-running after any layout change.

## Components

| File | Purpose |
|---|---|
| `SavedScreen.swift` | The tab: the grid, the floating `+`, the remove confirmation, the sheet, the controls inset at the bottom. |
| `SavedClockCell.swift` | `SavedCellDensity` (the sizes per column count) and one cell: label, numerals + meridiem, caption. |
| `AddSavedPlaceSheet.swift` | The add-a-place sheet over the converter's driver. |
| `SavedCitiesWidgetMirror.swift` | The app's `FavouritesMirror`: keychain write + WidgetKit reload. The only WidgetKit import in the app. |
| `ClockOffsetControls.swift` | Readout and signed offset (`Now` at zero) over the dial. |
| `ClockOffsetDial.swift` | The endless tick strip in a `Canvas`: drag to turn, tap to reset, VoiceOver adjustable by one tick. |
| `ClockOffset.swift` | The offset value and its rules: settled + in-progress minutes, snapping, twelve hours per track width, reset, launch start. |

The tab container is `RootTabView.swift` one level up, which also brings the
Convert tab forward whenever a launcher posts a request.
