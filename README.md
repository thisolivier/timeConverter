# TimeConverter

A small universal macOS/iOS app (SwiftUI, Mac Catalyst) for freeform timezone
conversion: type something like `12pm ET in London` or `06:34 Portugal in PST`
and see the converted time.

## Dev environment

The Xcode project is **generated** — `TimeConverter.xcodeproj` and
`TimeConverter/Info.plist` are not tracked in git. `project.yml` is the single
source of truth (including version numbers); regenerate with `xcodegen
generate` (the scripts do this for you). Requires Xcode 26+ and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

One iOS target covers iPhone, iPad, and Mac (via Catalyst,
`TARGETED_DEVICE_FAMILY: "1,2,6"`). Local builds sign ad-hoc with no team, so
everything works headlessly with no keychain access.

```bash
scripts/test.sh                 # unit tests, iOS simulator
scripts/test.sh --platform all  # unit tests, iOS simulator + Mac Catalyst
scripts/run-ios.sh              # build, install and launch on a simulator
scripts/run-mac.sh              # build and launch the Mac Catalyst app
```

Run `--platform all` before shipping anything that touches startup wiring or
storage — in the sibling music projects the Mac build broke twice while the
iOS lane stayed green.

## Layout

- `TimeConverter/` — app source. `ContentView.swift` is the whole interface;
  `ConverterPresenter.swift` turns parse output into display values;
  `ConverterDisplayDriver.swift` owns *when* the output area changes;
  `PromptChipRow.swift` renders the correction chips; `Parsing/` is the
  headless parser and conversion engine (see
  `TimeConverter/Parsing/readme.md`)
- `TimeConverterTests/` — test suite (Swift Testing)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers

Note: the target's `sources` glob copies non-Swift files in `TimeConverter/`
into the bundle, flattened. Only one `readme.md` can therefore live under
`TimeConverter/` (currently `Parsing/readme.md`) — a second one collides at
build time. The UI layer is documented below instead.

## UI layer

Still deliberately minimal: one text field, one output area, content
constrained to ~480pt so the Catalyst window reads as a small utility.

**The guiding rule is that the typed sentence is the single source of truth, on
every platform.** Every interaction edits that sentence rather than introducing
parallel state — which is why a correction chip rewrites a span of the input
string and lets the ordinary re-parse take it from there, instead of holding a
selection somewhere.

- **The UI is the only thing that knows what time it is.** `ContentView` calls
  `Date()` and passes it down; the driver, presenter, parser and conversion
  engine all take the current date as a parameter. That single injection point
  is what keeps everything below the view pure and testable.
- **The view holds no logic.** `ConverterPresenter` renders finished values and
  the view is a `switch` over three `ConverterDisplayState` cases, so UI
  behaviour is covered by ordinary unit tests (`ConverterPresenterTests`,
  `ReplacementChipTests`, `ConverterDisplayDriverTests`) with no UI tests at
  all.
- **Results are instant; prompts wait 600 ms.** `ConverterDisplayDriver` holds
  prompt display behind a cancellable task so ordinary typing stops flashing
  red text per keystroke, while conversions still render on the keystroke that
  completes them. A chip tap, `onSubmit` and launch all bypass the wait — the
  user has acted rather than typed. The delay is injectable, which is what
  makes the behaviour unit-testable. While a prompt is held back the output
  area shows the quiet hint, deliberately not the previous conversion: a stale
  answer under freshly edited text is worse than none.
- **Prompts offer tappable corrections.** P4 (ambiguous zone) renders each
  candidate as a button — `Chicago (UTC-6)` `Shanghai (UTC+8)` — and P5
  (unknown zone) renders up to three did-you-mean suggestions the same way
  (`Lodnon` → `London?`). Tapping rewrites the offending token *in the input
  string*, so the re-parse happens naturally and a second ambiguity becomes a
  second tap (`9am CST to IST` → tap Chicago → `9am Chicago to IST` → tap
  Kolkata). Identical SwiftUI buttons on iPhone, iPad and Mac; `ChipFlowLayout`
  wraps them onto as many lines as they need, because Russia offers ten.
  **Did-you-mean never auto-accepts**, not even a unique one-letter match — see
  the policy in `TimeConverter/Parsing/readme.md`.
- **The field focuses itself** on launch and on a genuine return from the
  background, so launch-to-typing is zero taps and the Mac window arrives ready
  to type. It never takes focus mid-session: `InputFocusPolicy` distinguishes
  returning from `.background` (focus) from merely regaining key status via
  `.inactive` (don't), which is the case that matters on Catalyst.
- **Styling is interim and knowingly so.** Prompt copy stays verbose, the text
  stays red, messages stay broken onto their own lines; a design sprint comes
  later. P4 also still lists its candidates inline above the chips, which is
  redundant but is the agreed interim copy.

### QA: prefilling the input headlessly

DEBUG builds read a `-initialInput` launch argument (via `UserDefaults`, which
maps `-key value` arguments automatically), so a real conversion can be
screenshotted without typing. The argument is compiled out of Release builds.

The prefill bypasses the prompt debounce, so a launch-argument run renders its
conversion — or its prompt and chips — on the first frame rather than after a
pause.

```bash
scripts/run-mac.sh    # build once, then launch with a prefilled field:
open -n build/DerivedData/Build/Products/Debug-maccatalyst/TimeConverter.app \
  --args -initialInput "12pm ET in London"
```

Four inputs that between them exercise the whole output area:

| `-initialInput` | Shows |
|---|---|
| `9:30 am New York to Lisbon` | A plain conversion, no chips |
| `9am CST to IST` | P4 chips; tapping twice converts |
| `12pm ET in Lodnon` | P5 did-you-mean chips |
| `12pm ET in London` | The expanded abbreviation echo |
| `9am Russia to London` | Ten chips, i.e. the wrapping layout |
