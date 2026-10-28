# TimeConverterAndroid

The Android shell of TimeConverter — the third platform beside the iOS and
macOS shells, built the same way: a thin native UI over a core that holds every
rule. Phones via Google Play are the scope.

## Architecture

```
TimeConverterAndroid/
  core/   plain Kotlin/JVM library — parser, engine, presenter-to-be. No Android imports.
  app/    the Compose shell: one activity, one screen. Strings in, layout out.
  gradle/libs.versions.toml   every tool and library version, pinned.
```

**`core` is a JVM module, not an Android library, on purpose.** `java.time`
already carries the IANA database and DST rules, so nothing in the engine needs
Android, and a JVM module runs its tests in a second with no emulator. It is
the Kotlin twin of the Swift package `TimeConverterCore`, file for file where
that makes sense (`TimeTokenParser`, `WallClockResolver`, `ConversionEngine`,
`Formatting`).

**The shared contract is `fixtures/conversion-cases.json`** at the repository
root (see `fixtures/readme.md`). The Swift core generates it; both cores assert
against it. There is no shared runtime — two implementations, one behaviour,
held together by one fixture file. `SharedFixtureEngineTests` is the engine
half of that contract and passes today; `SharedFixtureParserTests` is the
parser half and stays `@Ignore`d until the parser port lands.

**`InterimInputParser` is a stand-in**, clearly marked as such: enough grammar
to make the emulator show real conversions (time + zone in|to zone, a dozen
aliases, the tz database's own city names, local defaulting). It is not
asserted by the fixtures and is replaced wholesale by the port (backlog 24b).

Version numbers are read from `../project.yml` at build time so the Play train
shares `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` with the Apple trains.

## Working patterns

```bash
scripts/setup-android.sh              # one-off: SDK packages, licences, the AVD (idempotent)
scripts/test-android.sh               # JVM tests, seconds — the fixture contract lives here
scripts/run-android.sh --input "12pm ET in London" --screenshot shot.png
scripts/run-android.sh --stop
cd TimeConverterAndroid && ./gradlew :core:test   # the core alone
```

The emulator is headless by default because this machine is driven over ssh;
`--window` for a display. `--input` prefills the field (debug builds), the
twin of the iOS `-initialInput` launch argument, so screenshots can be driven
to a state.

Toolchain: JDK 17 (brew `openjdk@17`), Android SDK under
`~/Library/Android/sdk`, Gradle via the wrapper (9.6.1), AGP 9.4, Kotlin 2.4,
Compose BOM 2026.09. `scripts/lib/android-env.sh` exports all of it; nothing
depends on the shell profile. AGP 9 compiles Kotlin itself ("built-in
Kotlin"), which is why `app` applies no `kotlin-android` plugin.

## Main components

- `core/.../parsing/TimeTokenParser.kt` — the `<time>` grammar, ported.
- `core/.../parsing/InterimInputParser.kt` — the stand-in parser (see above).
- `core/.../engine/WallClockResolver.kt` — the DST policy (earlier on overlap,
  next valid instant on gap), on `java.time`'s `ZoneRules`.
- `core/.../engine/ConversionEngine.kt` — `ZoneReading`, `ConversionResult`,
  the engine.
- `core/.../engine/Formatting.kt`, `ZoneNames.kt` — the pinned, locale-free
  output shapes and the item-21 zone sub-line.
- `core/.../fixtures/` — the fixture schema and loader.
- `app/.../ConverterScreen.kt` — the poster layout; `PosterPalette.kt` the
  colour tokens; `MainActivity.kt` the activity and the `initialInput` extra.

## Not yet

Parser port (resolver chain, prompts P1–P5, chips, `now`, bare zones, the
offline gazetteer), release signing and the Play upload, a Compose UI test on
the emulator, the design's fonts. See `docs/android-plan.md`.
