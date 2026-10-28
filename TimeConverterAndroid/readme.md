# TimeConverterAndroid

The Android shell of TimeConverter — the third platform beside the iOS and
macOS shells, built the same way: a thin native UI over a core that holds every
rule. Phones are the scope, sideloaded from GitHub Releases through Obtainium
(not Google Play; see `docs/android-distribution.md`).

## Architecture

```
TimeConverterAndroid/
  core/   plain Kotlin/JVM library — parser, engine, presenter. No Android imports (see core/readme.md).
  app/    the Compose shell: one activity, one screen. Strings in, layout out.
  gradle/libs.versions.toml   every tool and library version, pinned.
```

**`core` is a JVM module, not an Android library, on purpose.** `java.time`
already carries the IANA database and DST rules, so nothing in the engine needs
Android, and a JVM module runs its tests in a second with no emulator. It is
the Kotlin twin of the Swift package `TimeConverterCore`, file for file where
that makes sense (`InputTokenizer`, `InputParser`, the resolver chain,
`TimeTokenParser`, `WallClockResolver`, `ConversionEngine`, `Formatting`).

**The shared contract is `fixtures/conversion-cases.json`** at the repository
root (see `fixtures/readme.md`). The Swift core generates it; both cores assert
against it. There is no shared runtime — two implementations, one behaviour,
held together by one fixture file. `SharedFixtureParserTests` renders every
case end to end (typed string → display or prompt + chips) and compares it
exactly; `SharedFixtureEngineTests` checks the zone arithmetic from the
resolved requests alone.

**The parser is a full port** (backlog 24b, 2026-10-28): the five-step
resolver chain, the country table, the offline gazetteer, representative
cities, local defaulting, bare zones, `now` and did-you-mean all behave as on
iOS. Two inputs Foundation answers and the JVM cannot are documented
snapshots: the abbreviation dictionary (51 entries, captured on macOS 26.2)
and the list of tzdata backward links that Apple's identifier list omits. See
`core/readme.md`.

**The presentation layer is a full port** (`core/.../presentation/`): the
`ConverterDisplay` slots under their Swift names, `ConverterProblem` /
`ReplacementChip` (raw-input ranges, `applied`), `ConverterPresenter`, the
600 ms `ConverterDisplayDriver` (time injected as a `PromptScheduler`, so the
JVM tests drive it with a fake clock) and `PosterLayoutMode` (item 19's
rule). The Compose view switches on `ConverterDisplayState` and nothing else.

Version numbers are read from `../project.yml` at build time so the Android
train shares `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` with the Apple
trains. `versionCode` is the build number; `versionName` is
`MARKETING_VERSION.build` (e.g. `0.1.0.17`) because Obtainium matches the
release tag against the installed versionName (see "Release lane").

## Working patterns

```bash
scripts/setup-android.sh              # one-off: SDK packages, licences, the AVD (idempotent)
scripts/test-android.sh               # JVM tests, seconds — the fixture contract lives here
scripts/run-android.sh --input "12pm ET in London" --screenshot shot.png
scripts/run-android.sh --release      # the signed, R8-shrunk release APK instead of debug
scripts/run-android.sh --stop
scripts/ship-android.sh 18 --dry-run  # everything but the publish
cd TimeConverterAndroid && ./gradlew :core:test   # the core alone
```

The emulator is headless by default because this machine is driven over ssh;
`--window` for a display. `--input` prefills the field (debug and release), the
twin of the iOS `-initialInput` launch argument, so screenshots can be driven
to a state.

Toolchain: JDK 17 (brew `openjdk@17`), Android SDK under
`~/Library/Android/sdk`, Gradle via the wrapper (9.6.1), AGP 9.4, Kotlin 2.4,
Compose BOM 2026.09. `scripts/lib/android-env.sh` exports all of it; nothing
depends on the shell profile. AGP 9 compiles Kotlin itself ("built-in
Kotlin"), which is why `app` applies no `kotlin-android` plugin.

## Release lane (backlog 24e)

**Signing.** `scripts/setup-android-signing.sh` (idempotent) made the release
key at `~/.config/timeconverter/android-release.jks`, with its passwords in
`android-release.properties` beside it (mode 600), both outside the repo.
`app/build.gradle.kts` signs release builds with it when that file exists and
otherwise builds release **unsigned with a warning**, so clean clones still
build. Certificate SHA-256
`B9:79:22:BD:D8:40:EE:5F:C8:8F:0B:06:A5:68:DA:76:DA:9B:86:A4:34:BF:69:9F:3C:BC:48:5F:92:F9:9F:C9`.
**Every release must be signed with this key** or installed copies can't
update, so the two files need a backup off this Mac.

**Shipping.** `scripts/ship-android.sh <build> [--dry-run]`: tests,
`assembleRelease`, versionCode/versionName check, `apksigner verify` plus a
check that the signer is *our* key, the emulator smoke below, a copy to
`dist/TimeConverter-<MARKETING_VERSION>-<build>.apk` (gitignored) beside the
smoke screenshot, then `gh release create`. Releases are tagged
`android-<versionName>` (`android-0.1.0.17`), titled `Time Converter 3000
0.1.0 (17)`. Obtainium uses the **tag** as the version and compares it with the
installed versionName by numeric shape, hence the build number in versionName;
`android-17` against `0.1.0` would quietly switch its version detection off.
The prefix keeps clear of any Apple tags. Verified end to end on the emulator
on 2026-10-28: add the repo, install, and a 16 to 17 update in place.

**Release smoke / R8.** Release builds run R8 with resource shrinking. The
first release smoke (build 16/17, 2026-10-28) found **no breakage**: the
`zone-names.json` classpath resource is packaged and read (the sub-line shows
`AUSTRALIAN EASTERN TIME (SYDNEY)`), conversions and P4 chips render, and
tapping a chip converts. No keep rules beyond the existing serializer ones in
`proguard-rules.pro` were needed. `ZoneNames` falls back to an empty map if
the resource is missing, which would fail silently, so `ship-android.sh`
asserts the sub-line text on screen (via `uiautomator dump`), not just a
screenshot. Debug and release are signed differently and can't install over
each other; `run-android.sh` uninstalls and retries when switching.

## Quick Settings tile (backlog 29)

The twin of the iOS Control Center control (item 11): a **Convert a time**
tile that opens the app with the field focused and the keyboard up.

- `ConvertTimeLaunch` builds the one launch intent shared by the tile and the
  launcher shortcut: `NEW_TASK | SINGLE_TOP`, never a `CLEAR_*` flag, so a live
  activity is brought forward with its typed text, plus the `focusInput` extra.
  `MainActivity.onNewIntent` ticks `arrivalCount` on that extra, so focus and
  keyboard come back even when the activity never left the foreground (tile
  tapped over the app); from the background `onStart` already does it.
- `ConvertTimeTileService`: always `STATE_ACTIVE`, not toggleable, not in
  active mode (re-asserts ACTIVE in `onStartListening`; it does no work, so
  binding per shade-open is cheap). API 34+ calls
  `startActivityAndCollapse(PendingIntent)` and lets SystemUI ask for the
  unlock on the keyguard; below 34 the deprecated `Intent` overload, wrapped
  in `unlockAndRun` when locked. Wrapping the 34+ path in `unlockAndRun` too
  made SystemUI ask twice and drop the launch on the API 36 emulator.
- `QuickSettingsTileOnboarding`: on API 33+, the first launch (after the first
  frame) calls `StatusBarManager.requestAddTileService` once; the
  SharedPreferences flag is written before asking, so whatever the answer it
  is never asked again. Closing the dialog re-ticks `arrivalCount` so the
  keyboard returns. Below 33 the user adds the tile by hand (edit Quick
  Settings, drag it in; see `docs/android-install.md`). Launches carrying
  `initialInput` (`run-android.sh --input`, the ship smoke) skip it without
  spending the ask, so scripted screenshots never show the system dialog.
- Launcher shortcut: a **dynamic** shortcut published on every launch.
  Static `shortcuts.xml` shortcuts always launch with `CLEAR_TASK`, which
  would destroy the activity and the typed text.
- Icon: `res/drawable/ic_tile_convert_time.xml`, a white 24dp clock whose rim
  is an arrow; the system tints it.

QA on the emulator (component `dev.thisolivier.timeconverter/.ConvertTimeTileService`):

```bash
adb shell cmd statusbar add-tile dev.thisolivier.timeconverter/.ConvertTimeTileService
adb shell cmd statusbar expand-settings
adb shell cmd statusbar click-tile dev.thisolivier.timeconverter/.ConvertTimeTileService
adb shell dumpsys input_method | grep -m1 mInputShown     # true = keyboard up
adb shell cmd statusbar remove-tile dev.thisolivier.timeconverter/.ConvertTimeTileService
```

Notes: after `am force-stop`, binding the tile service takes ~5 s on the
emulator, so wait before checking. On the keyguard, `click-tile` did nothing
on the API 36 image; tap the tile with `adb shell input tap` instead (the PIN
bouncer is a secure window and screenshots black). To see the add-tile
dialog again: `adb uninstall dev.thisolivier.timeconverter`, then launch
without `--input`.

## Main components

- `core/.../parsing/` — the parser port: `InputParser`, `InputTokenizer`,
  `NormalizedInput`, `TimeTokenParser`, the resolver chain and its tables,
  `Prompt`, `ZoneSuggestionEngine`. Component table in `core/readme.md`.
- `core/.../presentation/` — `ConverterDisplayState` (state, display slots,
  problem, chip), `ConverterPresenter`, `ConverterDisplayDriver` +
  `PromptScheduler`, `PosterLayoutMode`.
- `core/.../engine/WallClockResolver.kt` — the DST policy (earlier on overlap,
  next valid instant on gap), on `java.time`'s `ZoneRules`.
- `core/.../engine/ConversionEngine.kt` — `ZoneReading`, `ConversionResult`,
  the engine.
- `core/.../engine/Formatting.kt`, `ZoneNames.kt` — the pinned, locale-free
  output shapes and the item-21 zone sub-line.
- `core/.../fixtures/` — the fixture schema and loader.
- `app/.../ConverterScreen.kt` — the poster (title block, input box, arrow
  band, result) and item 19's choreography: `WindowInsets.ime` drives
  `PosterLayoutMode`; tap-away and any drag dismiss the keyboard.
- `app/.../ConverterScreenModel.kt` — the typed text and display state as
  Compose state, the main-looper scheduler, and the one place that reads the
  clock and the device zone.
- `app/.../ConverterInputBox.kt`, `PosterResultSection.kt`, `PromptChipRow.kt`,
  `PosterComponents.kt` — the pieces, ported from the iPhone's views.
- `app/.../PosterPalette.kt`, `PosterTypography.kt` — the Swift
  `PosterPalette` light and dark values; system condensed-black display face
  and monospace until real fonts are bundled.
- `app/.../MainActivity.kt` — the activity, the `initialInput` extra, and the
  arrival tick (`onStart`, plus `onNewIntent` with `focusInput`) that
  autofocuses on launch, return from background and tile/shortcut launches.
- `app/.../ConvertTimeLaunch.kt`, `ConvertTimeTileService.kt`,
  `QuickSettingsTileOnboarding.kt` — the Quick Settings tile, the shared
  launch intent and launcher shortcut, the one-time add-tile prompt.

## Not yet / still interim

- Chip ranges count UTF-16 units where Swift counts Characters; they differ
  only with an emoji or other multi-unit character before the token, and each
  side is self-consistent (see `core/readme.md`).
- Fonts (bundle Anton / JetBrains Mono equivalents), a Compose UI test on the
  emulator. See `docs/android-plan.md`.
- The keyboard's suggestion strip still shows (Gboard ignores
  `autoCorrectEnabled = false` for suggestions).
