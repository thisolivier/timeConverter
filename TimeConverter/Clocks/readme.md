# Clocks

The Clocks tab (backlog item 31), built as the design-free MVP in
`docs/favourites-world-clock-spec.md`: stock `List`, stock `Stepper`, stock
`Slider`, system tab bar, poster fonts and background, rust tint only on the
selection and the slider.

## Working patterns

- **Logic-free views.** Every string comes from `WorldClock.readings` in
  `TimeConverterCore` (see its `WorldClock/readme.md`); the rows are the
  converter's own digits, zone lines and day markers.
- **Live to the minute.** `TimelineView(.everyMinute)` re-reads the clock, so
  rows tick at zero and the real time keeps advancing under a non-zero offset.
  `TimeZone.current` is read here, beside `context.date`, as `ContentView` does.
- **Offset = days + slider minutes** (`ClockOffset`, unit-tested in
  `TimeConverterTests`). The slider covers −24 h…+24 h in 15-minute snapping
  steps, the stepper moves the day anchor without limit.
- **Tap on the slider = back to now.** A simultaneous `TapGesture` (fails on
  any movement, so a drag never resets), plus a fallback from the slider's own
  editing callbacks for a quick unmoved press on the thumb.
- **Persistence** is the app-owned `FavouritesStore` on `UserDefaults.standard`,
  from the environment. Swipe to delete removes by favourite, not by index.
  No reorder in the MVP (delete and re-star).

## Components

| File | Purpose |
|---|---|
| `ClocksScreen.swift` | The tab: local row, empty-state line or favourite rows, and the controls inset at the bottom. |
| `WorldClockRowView.swift` | One `WorldClockRow` in the poster's fonts at a modest size. |
| `ClockOffsetControls.swift` | Readout, signed offset (`Now` at zero), day stepper, slider, tap-to-reset. |
| `ClockOffset.swift` | The offset value and its rules: interval, reset, launch clamping, tap detection. |

The tab container is `RootTabView.swift` one level up, which also brings the
Convert tab forward whenever a launcher posts a request.
