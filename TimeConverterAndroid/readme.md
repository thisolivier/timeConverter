# TimeConverterAndroid

The Android shell of TimeConverter — the third platform beside the iOS and
macOS shells, built the same way: a thin native UI over a core that holds every
rule. Phones are the scope, sideloaded from GitHub Releases through Obtainium
(not Google Play; see `docs/android-distribution.md`).

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
to make the emulator show real conversions and real prompts (time + zone
in|to zone, the Swift alias table incl. the ambiguous `cst`/`ist`, a few
Foundation-style codes, the tz database's own city names, local defaulting),
emitting P1/P2/P4/P5 with the spec's copy and raw-text token ranges. It is
replaced wholesale by the port (backlog 24b); the presenter takes the parser
as a function parameter, so that swap touches nothing above it.

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

## Main components

- `core/.../parsing/TimeTokenParser.kt` — the `<time>` grammar, ported.
- `core/.../parsing/InterimInputParser.kt`, `InterimZoneTable.kt` — the
  stand-in parser and its vocabulary (see above).
- `core/.../parsing/Prompt.kt`, `RawTextRange.kt`, `NormalizedInput.kt` — the
  prompts as values with the spec's copy; raw-input ranges and the map from
  the normalised copy back to them.
- `core/.../parsing/ZoneSuggestionEngine.kt` — did-you-mean with the Swift
  policy (≤2 edits, ≤1 on short tokens, no code-for-code guesses, top 3,
  never auto-accepted) plus the bounded `EditDistance`.
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
  `onStart` arrival tick that autofocuses on launch and return from background.

## Not yet / still interim

- Parser port (24b): resolver chain, country table, offline gazetteer, `now`,
  bare zones. Until then `hello`, `Portugal`, `Porto`, `now in …` don't parse.
- Zone sub-line naming: `ZoneNames` uses `java.time`'s names, which on Android
  come out as `London Time (London)` / `Kolkata Time (Kolkata)`, and lists only
  the zone's own city where Swift lists `(New York, Toronto)`. A shared name
  table is coming separately; the presenter fixture test wildcards that part.
- Fonts (bundle Anton / JetBrains Mono equivalents), a Compose UI test on the
  emulator. See `docs/android-plan.md`.
- The keyboard's suggestion strip still shows (Gboard ignores
  `autoCorrectEnabled = false` for suggestions).
