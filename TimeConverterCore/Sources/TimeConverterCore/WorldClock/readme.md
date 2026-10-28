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
  `targetZoneLine(for:)`. Digits, zone lines, day markers and offset phrases
  therefore match the result band character for character, and the shared
  fixtures pin them for Android.
- **The offset shifts the local wall clock, not the instant.** `+1 d` is the
  same local time tomorrow, across a DST change too; the shifted wall clock is
  then resolved with the converter's DST policy (`WallClockResolver`), so a gap
  moves forward and a repeat takes the earlier. At zero the real `now` is read
  straight through (no round trip that could pick the wrong half of a repeated
  hour).
- **Day markers are relative to the local row**, which is the converter's
  `dayOffset` with local as the source. The readout's `Today` / `Tomorrow` is
  relative to the real today.
- **Strings are hand-formatted** (`Fri 31 Oct, 9:15 AM`, `−45 min`), never a
  `DateFormatter`, for the same locale-independence as `Parsing/Formatting.swift`.
- **The store takes its `UserDefaults`.** The app injects `.standard`; tests use
  a throwaway suite. One JSON array under `favouriteDestinations`.

## Components

| File | Purpose |
|---|---|
| `FavouriteDestination.swift` | The stored value; rebuilds the `ResolvedZone` the engine needs (a code label recovers its curated cities from the resolver chain); `resolvingTypedZone` for the DEBUG seed and the fixture catalog. |
| `FavouritesStore.swift` | `@Observable` list over injected defaults: `toggle`, `remove`, `remove(atOffsets:)`, `isFavourite`, `replaceAll`. |
| `WorldClock.swift` | `readings(favourites:offset:now:localZone:)` and the shifted-wall-clock resolution. |
| `WorldClockDisplay.swift` | `WorldClockDisplay` (readout, signed offset, rows) and `WorldClockRow`. |
| `WorldClockFormatting.swift` | The readout and the signed offset strings. |

Fixtures: `fixtures/world-clock-cases.json`, from `SharedWorldClockCatalog` in
the tests (see `fixtures/readme.md`).
