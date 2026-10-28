# fixtures

Cross-platform behaviour fixtures: the one file both the Swift and the Kotlin
cores are tested against.

- `conversion-cases.json` — **generated, do not hand-edit.** One case per row of
  `TimeConverterCore/Tests/TimeConverterCoreTests/SharedFixtures/SharedFixtureCatalog.swift`:
  the typed input, the injected clock and device zone, and the full expected
  outcome (every `ConverterDisplay` field for a conversion; prompt id, message
  and chips for a prompt).

## The loop

1. Change parser or presenter behaviour on the Swift side, with its own tests.
2. `scripts/regenerate-fixtures.sh` — renders the catalog through the Swift core.
3. `scripts/test.sh` — `SharedFixtureTests` verifies the file against the core
   (so an un-regenerated file fails on the Apple side).
4. `scripts/test-android.sh` — the Kotlin suites assert the same file. A diff
   in this file is the Android port's to-do list.
5. Commit the JSON with the code.

Add a case by adding a catalog row; the file's order is the catalog's order,
and ids must be unique. The schema is `SharedFixtureModels.swift` on one side
and `core/.../fixtures/ConversionCase.kt` on the other — change both.

## One platform-dependent field

`sourceZoneLine` / `targetZoneLine` on a place-labelled side begin with the
OS's generic zone name (`Eastern Australia Time (Sydney, Melbourne)`), which
comes from ICU and differs between ICU versions — the iOS 26 simulator and
macOS 26 already disagree about Sydney, and Android's `java.time` disagrees
about London. The file carries the generating Mac's wording; **verifiers
compare those two lines with the leading name wildcarded** (`* (Sydney,
Melbourne) · previous day`). Everything else in the file is exact. The Kotlin
verifier must apply the same rule (see `SharedFixtureTests.neutralZoneLine`).

