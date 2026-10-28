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
- Fonts (bundle Anton / JetBrains Mono equivalents), release signing and the
  Play upload, a Compose UI test on the emulator. See `docs/android-plan.md`.
- The keyboard's suggestion strip still shows (Gboard ignores
  `autoCorrectEnabled = false` for suggestions).
