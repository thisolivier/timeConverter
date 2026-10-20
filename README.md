# TimeConvertor

A small universal macOS/iOS app (SwiftUI, Mac Catalyst) for freeform timezone
conversion: type something like `12pm ET in London` or `06:34 Portugal in PST`
and see the converted time.

## Dev environment

The Xcode project is **generated** — `TimeConvertor.xcodeproj` and
`TimeConvertor/Info.plist` are not tracked in git. `project.yml` is the single
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

- `TimeConvertor/` — app source. `ContentView.swift` is the whole interface;
  `ConverterPresenter.swift` turns parse output into display strings;
  `Parsing/` is the headless parser and conversion engine (see
  `TimeConvertor/Parsing/readme.md`)
- `TimeConvertorTests/` — test suite (Swift Testing)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers

Note: the target's `sources` glob copies non-Swift files in `TimeConvertor/`
into the bundle, flattened. Only one `readme.md` can therefore live under
`TimeConvertor/` (currently `Parsing/readme.md`) — a second one collides at
build time. The UI layer is documented below instead.

## UI layer

Deliberately minimal for the MVC phase, pre-TestFlight: one text field, one
output area, content constrained to ~480pt so the Catalyst window reads as a
small utility.

- **The UI is the only thing that knows what time it is.** `ContentView` calls
  `Date()` and passes it down; the presenter, parser and conversion engine all
  take the current date as a parameter. That single injection point is what
  keeps everything below the view pure and testable.
- **The view holds no logic.** `ConverterPresenter` renders finished strings and
  the view is a `switch` over three `ConverterDisplayState` cases, so UI
  behaviour is covered by ordinary unit tests (`ConverterPresenterTests`) with
  no UI tests at all.
- **Parse on every keystroke**, plus `onSubmit`. Parsing is pure and fast, so
  there is no debounce.
- **No disambiguation UI.** All five prompts render as a single line of text.
  P4 lists its candidates inline (`'cst' could mean more than one place — pick
  one: Chicago (UTC-6), Shanghai (UTC+8)`) so the user can retype against one
  of the names. Pickers are later work.

### QA: prefilling the input headlessly

DEBUG builds read a `-initialInput` launch argument (via `UserDefaults`, which
maps `-key value` arguments automatically), so a real conversion can be
screenshotted without typing. The argument is compiled out of Release builds.

```bash
scripts/run-mac.sh    # build once, then launch with a prefilled field:
open -n build/DerivedData/Build/Products/Debug-maccatalyst/TimeConvertor.app \
  --args -initialInput "12pm ET in London"
```
