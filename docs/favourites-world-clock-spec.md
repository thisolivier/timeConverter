# Favourites and the world clock — spec

Reviewed with Olivier 2026-10-28 (decisions 1–8, 10, 11 accepted as written;
9 and 12 amended below). Agreed in outline 2026-10-28 (Olivier): "Being able to favourite destinations,
these add to a second tab, which shows by default the world clock in these
time zones, with a slider at the bottom which allows you to shift the time
forwards and backwards (input time)." iOS first, then Android. Mac untouched
this phase. The decisions below are mine where Olivier's sentence left them
open; each is marked **(decision)** so they are easy to reverse.

## Favouriting

- **Where**: a star on the converter's result band, at the far right of the
  time row (`12:45 AM        ☆`; moved there from beside the header on
  2026-10-29 so it never lengthens the `IN PST` line). Only the *target* can
  be starred; "destinations" means
  where the user is sending a time. **(decision)** Nothing on the source side,
  nothing on the prompt states.
- **What is stored**: the resolved zone identifier plus the `ZoneLabel` the
  user asked with, so the clock keeps the user's own words the way item 21
  does: `London`, or `ET (Eastern Time)` for a code. Starring `New York` and
  starring `ET` make two favourites with the same identifier and different
  labels; that is allowed, the label is part of the identity. **(decision)**
- **Toggling**: the star is filled when a favourite with the same identifier
  *and* label exists; tapping again removes it. A `(local)` target cannot be
  starred: the local clock is always the first row of the world clock anyway.
- **Order**: insertion order, user-reorderable in the Clocks tab (drag in
  edit mode, swipe to delete). No automatic sorting by offset. **(decision)**
- **Persistence**: a JSON array in `UserDefaults` (Android: `SharedPreferences`)
  under one key, read through a small `FavouritesStore` with an injectable
  defaults suite so tests never touch the real one. No iCloud sync this phase.

## The Clocks tab

- **Tabs**: a two-tab `TabView`: **Convert** (today's poster, unchanged) and
  **Clocks**. Tab names and symbols: `Convert` / `arrow.left.arrow.right`,
  `Clocks` / `clock`. **(decision)** The tab bar is the standard system one;
  the poster palette only colours the selection tint (rust).
- **Rows**: the first row is always the device's local zone, labelled like the
  converter labels it (`Los Angeles (local)`). Then one row per favourite, in
  stored order. Each row shows, in the poster's visual language:
  - the place name as favourited (natural case, the view uppercases),
  - the clock digits and meridiem at a reduced poster scale,
  - the zone line with item-21 semantics (zone name + representative cities
    under a place; cities only under a code) and the day marker when the row's
    date differs from the *real local today* (`· next day` / `· previous day`,
    `· +2 days` beyond), the local row included once the dial has crossed
    midnight. (Amended 2026-10-29: build 20 measured against the shifted local
    row, which made Los Angeles read "previous day" while London was pushed
    into tomorrow and lose the marker as it crossed into tomorrow itself.)
  - the relative offset phrase against local (`5 hours ahead`), small.
- **Empty state**: with no favourites, the local row plus one line of copy:
  "Star a destination in Convert and its clock appears here."
- **Live**: with the slider at zero the clocks tick with the real time, to the
  minute (`TimelineView(.everyMinute)`).

## The dial

- **Meaning**: an offset applied to the *local* clock; every row is that
  shifted local instant read in its own zone. This is exactly a conversion
  from local at the shifted wall-clock time to each favourite, so it reuses
  `ConversionEngine` and inherits its DST policy for free.
- **Range**: unbounded in both directions (Olivier, 2026-10-28: "shift
  indefinitely into the future or past, useful for DST change conditions").
  **Mechanic (Olivier, 2026-10-29)**: an **endless dial**, not a slider — "it
  can be turned and turned again. One swipe is 12 hours in one direction, a
  second pushes it another 12 hours — this eliminates the +/- UI." A
  full-width swipe across the control is 12 hours, rightwards forwards; each
  swipe adds to the last, with no ends. The value snaps to 15-minute steps. A
  **tap** on the dial (not a drag) resets to now. The MVP draws it as a strip
  of 15-minute ticks sliding under a fixed pointer; the visuals are a design
  question for later. (Build 20 shipped a −24 h…+24 h slider plus a day
  stepper; both are gone.)
- **Readout** above the dial: the shifted local time and its day —
  `Today 2:30 PM`, `Tomorrow 9:15 AM`, `Yesterday 11:00 PM`, and beyond one day
  the weekday and date, `Fri 31 Oct, 9:15 AM` — plus the signed offset once
  non-zero: `+5 h`, `−45 min`, `+3 d 2 h`.
- **Base**: the real current time keeps advancing underneath the offset, so a
  dial left at +2 h for ten minutes shows +2 h from the new now.

## Core (shared, fixture-tested)

New in `TimeConverterCore`, pure, `now`/`localZone` injected as everywhere else:

- `FavouriteDestination: Codable, Equatable, Identifiable` —
  `timeZoneIdentifier`, `label: ZoneLabel` (made `Codable`), stable `id`
  derived from both.
- `FavouritesStore` — load/save/toggle/move/remove over an injected
  `UserDefaults`; `isFavourite(identifier:label:)`.
- `WorldClock.readings(favourites:, offset: TimeInterval, now: Date, localZone: TimeZone) -> WorldClockDisplay`
  returning the readout strings and one `WorldClockRow` per row (local first)
  with the slots listed above, built on `ConversionEngine` and the existing
  `ZoneReading` formatting so the digits, zone lines and day markers match the
  converter to the character.
- **Fixtures**: `fixtures/world-clock-cases.json`, generated by the Swift core
  from a catalog (`SharedWorldClockCatalog`), same regenerate script and env
  var as the conversion fixtures, verified by `SharedWorldClockFixtureTests`.
  Cases: no favourites; three favourites at offset zero; +24 h crossing a day;
  −45 min; a favourite in a half-hour zone; a DST gap landing; a code-labelled
  favourite. Android's `SharedFixtureWorldClockTests` asserts the same file in
  the next phase, and the ship gate already requires every `SharedFixture*`
  class to run clean.

## MVP cut for the first release (design-free)

Olivier, 2026-10-28: review first, then ship an MVP with no design work.
The MVP keeps every behaviour above and drops only the styling and the
polish that would want a design pass:

- **Kept**: star on the result band, persistence, two tabs, local row
  first, the endless dial with snapping, the readout,
  tap-to-reset, live ticking,
  day markers, zone lines, offset phrases, swipe to delete, fixtures.
- **System chrome, poster content**: the Clocks tab is a plain SwiftUI `List`
  with system row chrome and a plain tick-strip dial. Inside each row the
  *strings* are the poster's (same digits, same zone line, same wording), set
  in the existing poster fonts at a modest size, on the poster background.
  Nothing is styled: the dial is ticks and a pointer, no custom tab bar, no
  illustration.
- **Dropped until the design sprint**: drag-to-reorder (delete and re-star to
  reorder), haptics, animations, iPad layout, the empty-state copy beyond one
  plain line.

## Out of scope this phase

Mac UI **and the Mac ship** (Olivier, 2026-10-28: the Mac shortcut was
designed as a quick utility, not a multi-page app; keep the Mac part unbuilt
until further notice — the Mac lane stays behind in `docs/releases.md` on
purpose this phase), iCloud sync, adding a favourite by typing in the Clocks
tab (the converter is the one input), widgets, Android (phase 2, item 32).

## Items

- **30** core: models, store, `WorldClock`, fixtures, tests.
- **31** iOS: star, tabs, Clocks screen, dial, readout, persistence wiring,
  simulator QA, TestFlight.
- **33** iOS build 20 feedback (2026-10-29): endless dial, day markers against
  the real today, star on the time row, swipe-to-dismiss with text typed, no
  autofocus on returning to Convert.
- **32** Android: port of 30 against the fixtures, Compose UI mirroring 31.
