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

- `TimeConvertor/` — app source (SwiftUI views; parsing and conversion logic to come)
- `TimeConvertorTests/` — test suite (Swift Testing)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers
