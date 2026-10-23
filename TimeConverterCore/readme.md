# TimeConverterCore

A local-path Swift package (the `oym_core` pattern borrowed from
`../musicLibrary/iOSnative/NaviAdmin`) holding everything the two app shells
share. **Two products:**

| Product | What it is |
|---|---|
| `TimeConverterCore` | Everything in this app that is not a view: parsing, presentation, launch. Imports Foundation, never SwiftUI. |
| `TimeConverterUI` | The shared SwiftUI design layer (item 20, phase A): colour tokens, typography, arrow shapes, `ConversionPairView`. Depends on `TimeConverterCore`. Has [its own readme](Sources/TimeConverterUI/readme.md). |

The core exists because the two platforms want genuinely different experiences
— iPhone/iPad screens on one side, a Mac menu-bar utility with no persistent
window on the other — and Mac Catalyst could not deliver the Mac one. Rather
than fork, the shells got thin and everything behind them moved here (backlog
item 16). `TimeConverterUI` is the other half of that bargain: the *designs*
turned out to share a component even where the platforms do not, so the
component lives here rather than being built twice.

```
TimeConverterCore/
  Sources/TimeConverterCore/
    Parsing/       the spec implementation — has its own readme
    Presentation/  parse output → display values, and when to show them
    Launch/        what a launcher asks the app to do, and the DEBUG prefill
    Resources/     fallback-cities.json, reached through Bundle.module
  Sources/TimeConverterUI/        the shared design layer — has its own readme
  Tests/TimeConverterCoreTests/   every unit test in the repo bar the shells'
  Tests/TimeConverterUITests/     the design layer's geometry and proportions
```

## Working patterns

- **One SPM target per *layer*, not per directory.** `Parsing`, `Presentation`
  and `Launch` are directories inside one target, deliberately: splitting them
  would force the parser's internals to be `public` so the presenter could see
  them, which is the opposite of the goal. `TimeConverterUI` *is* a second
  target, because that boundary is load-bearing — it is what keeps the core
  UI-free, and a folder cannot enforce that. The dependency points one way and
  nothing under `Sources/TimeConverterCore` imports SwiftUI.
- **The public surface is tiny and hand-picked.** Only what a *shell* calls is
  `public`: `ConverterDisplayDriver` (with a parameterless `init`),
  `ConverterDisplayState` and its payloads, `ReplacementChip`, `LaunchRequest`,
  `LaunchRequestInbox`, `LaunchURLRouter`, `LaunchArguments`. `InputParser`,
  `ConverterPresenter`, `Prompt`, every resolver and every model stay internal —
  the tests reach them with `@testable import`, which is why extraction did not
  cost a wave of `public` keywords. A shell cannot reach past the driver into
  the parser, and the API cannot grow by accident through a default argument.
- **Nothing here reads the clock or the device zone.** `now:` and `localZone:`
  are parameters all the way down. `Date()` and `TimeZone.current` are read in
  exactly two places in the whole repo — `ContentView` on iOS and
  `MenuBarConverterView` on macOS — which is what keeps every test
  deterministic on any machine.
- **No UI framework.** Foundation and `Observation` only; not even SwiftUI. The
  `@Observable` driver is observable *by* SwiftUI without importing it.
- **The bundled gazetteer comes from `Bundle.module`, and only from there.**
  Before extraction it was compiled into the app target and found through
  `Bundle.main` with a `Bundle(for:)` fallback for the test host. Both
  fallbacks are gone on purpose: `Bundle.module` is the single correct answer in
  the app, in the Mac app, under `swift test` and under `xcodebuild test`, and a
  `Bundle.main` fallback would hide the one bug this is likely to have — a
  resource missing from `Package.swift` — by quietly finding a stale copy
  double-bundled in an app.
- **Swift tools 6.2, language mode 6.** `6.2` is forced rather than chosen:
  `.iOS(.v26)` / `.macOS(.v26)` do not exist in earlier `PackageDescription`
  and fail with "'v26' is unavailable".

## Components

| Group | Purpose |
|---|---|
| `Parsing/` | `docs/input-parsing-spec.md` in code: string in, conversion or prompt out. See `Parsing/readme.md`. |
| `Presentation/ConverterPresenter.swift` | The only place parse output becomes display strings. Internal — shells go through the driver. |
| `Presentation/ConverterDisplayState.swift` | The three things a UI can show, plus `ConverterDisplay`, `ConverterProblem` and `ReplacementChip`. |
| `Presentation/ConverterDisplayDriver.swift` | *When* the output changes: results instantly, prompts after 600 ms, bypasses for submit/chip-tap/launch. The shells' one entry point. |
| `Presentation/PosterLayoutMode.swift` | Item 19's collapse rule as a pure function: `(hasInput, keyboardIsVisible) -> .full \| .compact`, plus what each mode shows. The iOS view owns the keyboard observation and the animation; the judgement lives here. |
| `Launch/LaunchRequest.swift` | `.startFreshConversion` vs `.summonWithoutReset`, their `inputToStartFrom` rule, and the one-slot `LaunchRequestInbox`. |
| `Launch/LaunchURLRouter.swift` | `timeconverter://convert` → a request. A QA and fallback route, not a feature. |
| `Launch/LaunchArguments.swift` | The DEBUG `-initialInput` prefill and `-forceCompact`, so both a conversion and item 19's collapsed layout can be screenshotted headlessly. |

### `ConverterDisplay` carries two generations of fields at once

Deliberately. `echoLine` / `detailLine` are the original one-sentence
rendering, still the spec's canonical echo and still what the Mac shell draws.
Beside them sit the decomposed fields the redesigned iOS layout needs (item 18)
— `sourceEchoLine`, `targetPlaceLabel`, `targetClockDigits`, `targetMeridiem`,
`targetZoneLine`, `footerSentence`, `daylightSavingNote`. Both generations come
off one `ConversionResult`; nothing is computed twice. When the Mac gets its
own design the old pair can go.

### The source side now decomposes like the target (item 20)

The iPad and Mac designs draw source and target as two *identical* columns,
which made the old asymmetry visible: the target had a place name, a clock
split into digits and a meridiem, and a zone line, while the source had one
run-together echo string (`Lisbon · 8:00 PM`) that no column layout can take
apart. So the source grew the same four slots — `sourcePlaceName`,
`sourceClockDigits`, `sourceMeridiem`, `sourceZoneLine` — and the target grew
`targetPlaceName`, which is `targetPlaceLabel` without the `In` (the pair's
columns are already captioned `FROM` and `TO`; a second preposition reads as a
stutter). `sourceEchoLine` is untouched: it is what the iPhone draws inside its
input box, and that screen did not change.

Two rules worth knowing. The source clock is read off the **resolved instant**,
not off the typed time, so on a spring-forward gap the column shows where the
clock actually landed. And the day-rollover note stays on `targetZoneLine`
alone — the rollover is a fact about where the target landed, and repeating it
on the source would claim the source moved day too.

`offsetPhrase` joins them: the footer sentence with both names stripped
(`4 hours behind`), for the keyboard-up layout that sets it under the arrow.

Since item 21 the two generations **disagree about UTC offsets**, on purpose.
The iOS slots dropped them — the result band names the *zone*, and the
disambiguation chips are the one place an offset actually decides something —
while `echoLine` keeps every offset for the Mac shell, whose single sentence
has nowhere else to put them.

One consequence worth knowing: the redesigned layout has no echo sentence to
hang `+1d` off, so the day rollover rides `targetZoneLine` as
`Japan Standard Time (Tokyo) · next day`. It is never dropped — which is
exactly why taking the offset off that line had to be done carefully.

## Tests

283 tests — 262 in `TimeConverterCoreTests` and 21 in `TimeConverterUITests` —
and they are the bulk of the repo's coverage. Both schemes run both of this
package's test targets, so they are exercised **twice per full run** — once on
the iOS simulator and once natively on macOS:

```
scripts/test.sh --platform all   # both lanes
swift test                       # this package alone, macOS, fastest loop
```

What the shells keep for themselves is only what cannot live here:
`TimeConverterTests` has the iOS focus policy, `TimeConverterMacTests` has the
⌃⌥T chord and the summon-toggle rule.
