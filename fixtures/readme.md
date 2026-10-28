# fixtures

Cross-platform behaviour fixtures: the one file both the Swift and the Kotlin
cores are tested against.

- `conversion-cases.json` — **generated, do not hand-edit.** One case per row of
  `TimeConverterCore/Tests/TimeConverterCoreTests/SharedFixtures/SharedFixtureCatalog.swift`:
  the typed input, the injected clock and device zone, and the full expected
  outcome (every `ConverterDisplay` field for a conversion; prompt id, message
  and chips for a prompt).

- `world-clock-cases.json` — **generated, do not hand-edit** (item 30). One
  case per row of `SharedWorldClockCatalog.swift`: the injected clock and
  device zone, the offset, the favourites, and the expected `WorldClockDisplay`.

### `world-clock-cases.json` schema

```
{ schemaVersion: 1, generatedBy, cases: [ {
    id, note?, now (ISO-8601), localZone (IANA),
    offsetSeconds,            // slider + day stepper, whole minutes, unbounded
    favourites: [ { timeZoneIdentifier,
                    labelKind: "place" | "code",
                    name?,                    // place
                    code?, expandedName? } ], // code
    expected: { readout,                       // "Today 3:42 PM", "Sun 18 Jan, 5:42 PM"
                offsetDescription?,            // "+19 h", "−45 min" (U+2212); absent at zero
                rows: [ { isLocal, placeName, clockDigits, meridiem,
                          zoneLine,            // item-21 line + " · next day"/" · previous day" vs the local row
                          offsetPhrase } ] }   // "" on the local row
} ] }
```

The offset shifts the local *wall clock* and is resolved with the converter's
DST policy (see `TimeConverterCore/Sources/TimeConverterCore/WorldClock/readme.md`);
at zero the real instant is read directly. `SharedWorldClockFixtureTests`
verifies the file both ways: the catalog renders to it exactly, and each
stored case replayed from its own `favourites` and `offsetSeconds` produces its
`expected`. The Android twin (`SharedFixtureWorldClockTests`) comes with item 32.

## The loop

1. Change parser or presenter behaviour on the Swift side, with its own tests.
2. `scripts/regenerate-fixtures.sh` — renders both catalogs through the Swift core
   and rewrites both files.
3. `scripts/test.sh` — `SharedFixtureTests` verifies the file against the core
   (so an un-regenerated file fails on the Apple side).
4. `scripts/test-android.sh` — the Kotlin suites assert the same file:
   `SharedFixtureParserTests` renders every case end to end through the
   ported parser and presenter and compares it exactly. A diff in this file is
   the Android port's to-do list.
5. Commit the JSON with the code.

Add a case by adding a catalog row; the file's order is the catalog's order,
and ids must be unique. The schema is `SharedFixtureModels.swift` on one side
and `core/.../fixtures/ConversionCase.kt` on the other — change both.

## Zone names: one canonical answer, from iOS

`sourceZoneLine` / `targetZoneLine` on a place-labelled side begin with the
zone's generic name (`Australian Eastern Time (Sydney, Melbourne)`). Every
platform's ICU words these differently (macOS 26 says `Eastern Australia
Time`, Android's `java.time` says `London Time`), so no platform asks its own
OS any more: the names come from
`TimeConverterCore/Sources/TimeConverterCore/Resources/zone-names.json`, a
snapshot of what the **iOS** simulator says for every zone. **iOS is the
origin; other platforms conform.** The Swift core bundles the file; the Android
core's build adds the same file to its classpath (no second copy).

- To refresh it (new iOS, new tz database — `ZoneNameSnapshotTests` fails
  until you do): `scripts/regenerate-zone-names.sh` (iOS simulator only), then
  `scripts/regenerate-fixtures.sh`, then both test suites.
- A name may be hand-edited in the snapshot where iOS's wording reads badly;
  regenerating overwrites the edit, so re-apply it.

Because of this, **every field in this file is compared exactly**, zone lines
included, by both verifiers: `SharedFixtureTests` on the Apple side, and on the
Kotlin side `ZoneNameParityTests` checks that the name in each fixture zone
line equals `ZoneNames.genericName` for that zone.
