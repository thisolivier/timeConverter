# TimeConverterCore

Everything in this app that is not a view. A local-path Swift package (the
`oym_core` pattern borrowed from `../musicLibrary/iOSnative/NaviAdmin`),
consumed by three targets: the iOS app, the native macOS app, and the iOS
Control Center extension.

It exists because the two platforms want genuinely different experiences —
iPhone/iPad screens on one side, a Mac menu-bar utility with no persistent
window on the other — and Mac Catalyst could not deliver the Mac one. Rather
than fork, the shells got thin and everything behind them moved here (backlog
item 16).

```
TimeConverterCore/
  Sources/TimeConverterCore/
    Parsing/       the spec implementation — has its own readme
    Presentation/  parse output → display values, and when to show them
    Launch/        what a launcher asks the app to do, and the DEBUG prefill
    Resources/     fallback-cities.json, reached through Bundle.module
  Tests/TimeConverterCoreTests/   every unit test in the repo bar the shells'
```

## Working patterns

- **One SPM target, three source groups.** `Parsing`, `Presentation` and
  `Launch` are directories, not separate SPM targets, deliberately: splitting
  them would force the parser's internals to be `public` so the presenter could
  see them, which is the opposite of the goal.
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

`ConverterDisplay` carries **two generations of fields at once**, and that is
deliberate. `echoLine` / `detailLine` are the original one-sentence rendering,
still the spec's canonical echo and still what the Mac shell draws. Beside them
sit the decomposed fields the redesigned iOS layout needs (item 18) —
`sourceEchoLine`, `targetPlaceLabel`, `targetClockDigits`, `targetMeridiem`,
`targetOffsetLine`, `footerSentence`, `daylightSavingNote`. Both generations
come off one `ConversionResult`; nothing is computed twice. When the Mac gets
its own design the old pair can go.

One consequence worth knowing: the redesigned layout has no echo sentence to
hang `+1d` off, so the day rollover rides `targetOffsetLine` as
`UTC+9 · next day`. It is never dropped.
| `Presentation/ConverterDisplayDriver.swift` | *When* the output changes: results instantly, prompts after 600 ms, bypasses for submit/chip-tap/launch. The shells' one entry point. |
| `Launch/LaunchRequest.swift` | `.startFreshConversion` vs `.summonWithoutReset`, their `inputToStartFrom` rule, and the one-slot `LaunchRequestInbox`. |
| `Launch/LaunchURLRouter.swift` | `timeconverter://convert` → a request. A QA and fallback route, not a feature. |
| `Launch/LaunchArguments.swift` | The DEBUG `-initialInput` prefill, so a conversion can be screenshotted headlessly. |

## Tests

217 tests, and they are the bulk of the repo's coverage. Both schemes run this
one test target, so the core is exercised **twice per full run** — once on the
iOS simulator and once natively on macOS:

```
scripts/test.sh --platform all   # both lanes
swift test                       # this package alone, macOS, fastest loop
```

What the shells keep for themselves is only what cannot live here:
`TimeConverterTests` has the iOS focus policy, `TimeConverterMacTests` has the
⌃⌥T chord and the summon-toggle rule.
