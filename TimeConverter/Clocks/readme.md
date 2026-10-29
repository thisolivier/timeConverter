# Clocks

The Clocks tab (backlog item 31), built as the design-free MVP in
`docs/favourites-world-clock-spec.md`: stock `List`, system tab bar, poster
fonts and background, rust tint on the selection and the dial's pointer.

## Working patterns

- **Logic-free views.** Every string comes from `WorldClock.readings` in
  `TimeConverterCore` (see its `WorldClock/readme.md`); the rows are the
  converter's own digits and zone lines, with day markers against the real
  local today.
- **Live to the minute.** `TimelineView(.everyMinute)` re-reads the clock, so
  rows tick at zero and the real time keeps advancing under a non-zero offset.
  `TimeZone.current` is read here, beside `context.date`, as `ContentView` does.
- **An endless dial, not a slider** (`ClockOffset`, unit-tested in
  `TimeConverterTests`; reworked 2026-10-29 from build 20's slider + day
  stepper). A full-width swipe is 12 hours, rightwards forwards; the next
  swipe adds to it, with no ends either way. The value snaps to 15 minutes,
  the tick strip follows the finger unsnapped (so later times come in from
  the left, like a tape pulled through).
- **Tap on the dial = back to now.** The drag needs 6 pt of travel before it
  is a drag, so a touch that lifts in place is the reset tap.
- **Persistence** is the app-owned `FavouritesStore` on `UserDefaults.standard`,
  from the environment. Swipe to delete removes by favourite, not by index.
  No reorder in the MVP (delete and re-star).

## Components

| File | Purpose |
|---|---|
| `ClocksScreen.swift` | The tab: local row, empty-state line or favourite rows, and the controls inset at the bottom. |
| `WorldClockRowView.swift` | One `WorldClockRow` in the poster's fonts at a modest size. |
| `ClockOffsetControls.swift` | Readout and signed offset (`Now` at zero) over the dial. |
| `ClockOffsetDial.swift` | The endless tick strip in a `Canvas`: drag to turn, tap to reset, VoiceOver adjustable by one tick. |
| `ClockOffset.swift` | The offset value and its rules: settled + in-progress minutes, snapping, twelve hours per track width, reset, launch start. |

The tab container is `RootTabView.swift` one level up, which also brings the
Convert tab forward whenever a launcher posts a request.
