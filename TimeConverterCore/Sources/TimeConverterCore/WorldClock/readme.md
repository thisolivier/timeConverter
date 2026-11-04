# WorldClock

Favourites and the world clock, items 30 (core) and 31 (iOS). The spec is
`docs/favourites-world-clock-spec.md`. Foundation and `Observation` only, like
the rest of the package; `now` and `localZone` are always parameters.

## Working patterns

- **A favourite is an identifier plus the user's label.** `New York` and `ET`
  are two favourites on one zone, because the label is what the user asked
  with (item 21's rule). The label is a `ZoneLabel`, now public and `Codable`.
- **The clock is the converter, re-run.** Each row is a conversion from the
  local zone at the shifted time to the favourite, through
  `ConversionEngine.read(_:from:to:…)` and the presenter's own
  `zoneLine(zoneDetail:dayOffset:)`. Digits, zone lines and offset phrases
  therefore match the result band character for character, and the shared
  fixtures pin them for Android.
- **The offset shifts the local wall clock, not the instant.** `+1 d` is the
  same local time tomorrow, across a DST change too; the shifted wall clock is
  then resolved with the converter's DST policy (`WallClockResolver`), so a gap
  moves forward and a repeat takes the earlier. At zero the real `now` is read
  straight through (no round trip that could pick the wrong half of a repeated
  hour).
- **Day markers are relative to the real local today**, on every row, the
  local one included — the same reference as the readout's `Today` /
  `Tomorrow`. (Build 20 measured them against the shifted local row, which
  read backwards under the dial; changed 2026-10-29.)
- **Strings are hand-formatted** (`Fri 31 Oct, 9:15 AM`, `−00d 00h 45m` —
  the dial's offset keeps every part, zero-padded, so it never changes width
  under the finger), never a
  `DateFormatter`, for the same locale-independence as `Parsing/Formatting.swift`.
- **Rows carry both a long and a short form** (item 37): `offsetPhrase`
  (`8 hours behind`) and `shortOffsetPhrase` (`8h behind`), `placeName`
  (`Portland, Oregon`, `ET (Eastern Time)`, `Los Angeles (local)`) and
  `compactPlaceName` (`Portland`, `ET`, `Los Angeles`). The Saved grid's
  three-column layout and the widgets use the short ones; the fixtures pin
  the phrases, the compact name is a view hook.
- **The Saved grid's shape is decided here** (`SavedGridLayout`): one column
  up to three clocks, two up to eight, three from nine — pure arithmetic
  shared with Android so the two tabs agree; the views own the sizes.
- **The store takes its `UserDefaults`.** The app injects `.standard`; tests use
  a throwaway suite. One JSON array under `favouriteDestinations`.
- **The store can mirror itself** (item 36). An optional `FavouritesMirror`
  gets a copy after every save and once at init, for the home-screen widget,
  which runs in another process. `KeychainFavouritesMirror` is the shipped
  mirror: one keychain item both the app and the widget extension can open
  without a portal step (an App Group is the proper home, pending; see the
  type comment). The package never imports WidgetKit — the app's mirror adds
  the reload nudge.

## Components

| File | Purpose |
|---|---|
| `FavouriteDestination.swift` | The stored value; rebuilds the `ResolvedZone` the engine needs (a code label recovers its curated cities from the resolver chain); `resolvingTypedZone` for the DEBUG seed and the fixture catalog. |
| `FavouritesStore.swift` | `@Observable` list over injected defaults: `toggle`, `remove`, `remove(atOffsets:)`, `isFavourite`, `replaceAll`; publishes to an optional mirror. |
| `FavouritesMirror.swift` | `FavouritesMirror` and `KeychainFavouritesMirror` (write after save, `read()` for the widget). |
| `SavedCitiesWidgetSupport.swift` | The widget's `kind`, the cells (saved places only, at most six) and the minute-boundary entry dates — the testable part of the widget. |
| `WorldClock.swift` | `readings(favourites:offset:now:localZone:)` and the shifted-wall-clock resolution. |
| `WorldClockDisplay.swift` | `WorldClockDisplay` (readout, signed offset, rows) and `WorldClockRow`. |
| `WorldClockFormatting.swift` | The readout and the signed offset strings. |
| `SavedGridLayout.swift` | Column count by clock count, short-phrase rule, row chunking (item 37). |
| `WidgetLayoutPlan.swift` | The widgets' layout by family and city count: columns, rows, name and caption style, hero, spanning last cell (item 36b). |
| `ShortPlaceNames.swift` + `../Resources/short-names.json` | Three-letter place names for the widgets' tightest cells; curated forms in the file, first-three-letters otherwise, a code as itself. |

Fixtures: `fixtures/world-clock-cases.json`, from `SharedWorldClockCatalog` in
the tests (see `fixtures/readme.md`).
