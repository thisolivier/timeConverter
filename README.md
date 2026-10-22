# TimeConverter

A small iOS/macOS app (SwiftUI) for freeform timezone conversion: type
something like `12pm ET in London` or `06:34 Portugal in PST` and see the
converted time.

**Two native shells over one shared core** (backlog item 16). `TimeConverterCore`
is a local Swift package holding the parser, the presenter and every rule; the
iOS app is a window, and the Mac app is a menu-bar utility with a ⌃⌥T global
hotkey and no persistent window. Mac Catalyst is retired — the platforms want
genuinely different access, and Catalyst could deliver neither `MenuBarExtra`
nor `NSStatusItem` nor Carbon. Behaviour never differs; only access does.

## Dev environment

The Xcode project is **generated** — `TimeConverter.xcodeproj` and
`TimeConverter/Info.plist` are not tracked in git. `project.yml` is the single
source of truth (including version numbers); regenerate with `xcodegen
generate` (the scripts do this for you). Requires Xcode 26+ and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

Three product targets plus two test targets, one scheme per platform. Local
builds sign ad-hoc with no team, so everything works headlessly with no
keychain access.

| scheme | platform | what it builds and tests |
|---|---|---|
| `TimeConverter` | iOS | the iOS app + the Controls extension; `TimeConverterTests` + the whole `TimeConverterCore` test target, on the simulator |
| `TimeConverterMac` | macOS | the native menu-bar app; `TimeConverterMacTests` + the same `TimeConverterCore` test target, natively |

```bash
scripts/test.sh                 # unit tests, iOS simulator (202 tests)
scripts/test.sh --platform mac  # unit tests, native macOS (203 tests)
scripts/test.sh --platform all  # both lanes
scripts/test.sh PromptTests     # one core suite (bare names mean the core)
scripts/run-ios.sh              # build, install and launch on a simulator
scripts/run-mac.sh              # build and launch the native Mac menu-bar app
scripts/qa-menubar.sh           # Mac-only: QA the menu bar and ⌃⌥T (Debug)
cd TimeConverterCore && swift test   # the core alone, fastest loop
```

The shared core is deliberately tested **twice**, once per platform, which is
why the two lanes overlap by 195 tests. Run `--platform all` before shipping
anything that touches parsing, the presenter or startup wiring — in the sibling
music projects the Mac build broke twice while the iOS lane stayed green.

## Shipping

Two lanes into the **same** App Store Connect record (app `6825044484`), one per
platform train. Release signing is **manual** in both, against named
provisioning profiles.

| | iOS | macOS (native) |
|---|---|---|
| | `scripts/ship.sh <build>` | `scripts/ship-mac.sh <build>` |
| target | `TimeConverter` | `TimeConverterMac` |
| archive | `generic/platform=iOS` | `generic/platform=macOS` |
| profiles | `TimeConverter App Store`, `TimeConverter Controls App Store` | `TimeConverter Mac App Store` (one — no extension on the Mac) |
| product | `.ipa` → `altool -t ios` | `.pkg` → `altool -t macos` |
| status | **working** — build 5 is VALID | **blocked on the portal** (below) |

Both targets carry the bundle id `dev.thisolivier.timeconverter`. A bundle id is
scoped per platform in App Store Connect, so the Mac app is the macOS train of
the one record rather than a second app — which is what makes it a universal
purchase. xcodegen has no objection to two targets sharing one
`PRODUCT_BUNDLE_IDENTIFIER`; the products never collide because they build into
per-platform directories.

The build number comes from `project.yml`'s `CURRENT_PROJECT_VERSION` via
`scripts/lib/version.sh`, shared by both scripts on purpose: macOS requires
`CFBundleVersion` to increase monotonically across *all* trains, so the two
lanes cannot be allowed to drift.

### Why the Mac needs its own lane at all

An iOS TestFlight build does install and run on an Apple silicon Mac — but as
"iPhone and iPad app on Mac", i.e. the *iOS* binary in the iOS runtime. It is a
different product from the menu-bar app: no status item, no ⌃⌥T, a window. That
compatibility path still works and is untouched; it simply cannot deliver the
Mac experience, which is why `ship-mac.sh` archives `TimeConverterMac`.

> **⚠️ `ship-mac.sh` cannot complete yet** — it needs one macOS provisioning
> profile and a Mac Installer Distribution certificate that do not exist. It
> stops in **preflight (step 2/7)**, before touching the build number, and
> prints the portal steps. The final list is under **"macOS train"** in
> `docs/testflight-setup-checklist.md`, including the dry-run archive's verbatim
> demand. Nothing else is affected: `ship.sh`, Debug builds, both test lanes,
> `run-ios.sh` and `run-mac.sh` all work, because Debug signs ad-hoc with no
> team and the macOS signing settings are scoped to the Mac target's Release
> config.
>
> Once the profile is installed, the first command to run is
> `scripts/ship-mac.sh --validate-only`: it archives, exports and asks App Store
> Connect's validator for a verdict **without delivering anything and without
> consuming a build number**. macOS build numbers are unrecoverable, so that
> order matters.

## Layout

- `TimeConverterCore/` — **the local SPM package: everything that is not a
  view.** `Parsing/` is the headless parser and conversion engine,
  `Presentation/` is the presenter plus the display driver that owns *when* the
  output changes, `Launch/` is the launch-request logic and the DEBUG prefill,
  `Resources/fallback-cities.json` is reached through `Bundle.module`, and
  `Tests/` holds 195 of the repo's tests. See `TimeConverterCore/readme.md` and
  `TimeConverterCore/Sources/TimeConverterCore/Parsing/readme.md`
- `TimeConverter/` — the **iOS** shell. `ContentView.swift` is the whole
  interface; `PromptChipRow.swift` renders the correction chips;
  `InputFocusPolicy.swift` decides when the field takes focus; `Launchers/` is
  the App Shortcut and the intent (see `TimeConverter/Launchers/readme.md`)
- `TimeConverterMac/` — the **macOS** shell: `MenuBarExtra`, the summoned
  panel, ⌃⌥T (see `TimeConverterMac/readme.md`)
- `TimeConverterControls/` — the Control Center widget extension, iOS-only (see
  `TimeConverterControls/readme.md`)
- `TimeConverterTests/`, `TimeConverterMacTests/` — each shell's own tests, thin
  by design (Swift Testing)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers

Note: the targets' `sources` globs copy non-Swift files into the bundle,
flattened, so every module `readme.md` is excluded in `project.yml` — without
that exclude two readmes in different modules collide at build time. The
package does the same thing with `exclude:` in `Package.swift`, where an
unhandled `readme.md` would otherwise be warned about and copied. The iOS view
layer has no module of its own and is documented below instead.

## UI layer

This section describes the **iOS** shell. The Mac shell deliberately has its
own, plainer view layer as a placeholder for the translucent summoned design —
see `TimeConverterMac/readme.md` — but drives the identical
`ConverterDisplayDriver`, so every rule below (debounce, chips, instant
results) holds there too.

Still deliberately minimal: one text field, one output area, content
constrained to ~480pt so an iPad window reads as a small utility.

**The guiding rule is that the typed sentence is the single source of truth, on
every platform.** Every interaction edits that sentence rather than introducing
parallel state — which is why a correction chip rewrites a span of the input
string and lets the ordinary re-parse take it from there, instead of holding a
selection somewhere.

- **The UI is the only thing that knows what time it is, or where it is.**
  `ContentView` calls `Date()` and reads `TimeZone.current`, and passes both
  down; the driver, presenter, parser and conversion engine all take them as
  parameters. `MenuBarConverterView` is the only other place in the repo that
  does this. That single injection point is what keeps everything below the
  view pure and testable — including local-zone defaulting, where the device
  zone fills in a side the user didn't name (`7pm in London` →
  `7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d`).
- **The view holds no logic.** `ConverterPresenter` renders finished values and
  the view is a `switch` over three `ConverterDisplayState` cases, so UI
  behaviour is covered by ordinary unit tests in the package
  (`ConverterPresenterTests`, `ReplacementChipTests`,
  `ConverterDisplayDriverTests`) with no UI tests at all — and because they live
  in the package, they run on both platforms.
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
  the policy in `TimeConverterCore/Sources/TimeConverterCore/Parsing/readme.md`.
- **The field focuses itself** on launch and on a genuine return from the
  background, so launch-to-typing is zero taps. It never takes focus
  mid-session: `InputFocusPolicy` distinguishes returning from `.background`
  (focus) from merely regaining key status via `.inactive` (don't), which is the
  case that matters in iPad multitasking. A launcher
  (below) is the one thing that may take focus mid-session — it is a button
  whose entire meaning is "let me type a time".
- **Styling is interim and knowingly so.** Prompt copy stays verbose, the text
  stays red, messages stay broken onto their own lines; a design sprint comes
  later. P4 also still lists its candidates inline above the chips, which is
  redundant but is the agreed interim copy.

## Getting into the app (iOS launchers)

Both are *launchers only* — they open the app with an **empty, focused** field
and nothing else. No launcher can accept a typed sentence, so this is the honest
best iOS can do for a typed-input tool: the keyboard, one tap sooner. See
`TimeConverter/Launchers/readme.md` and `TimeConverterControls/readme.md`.

- **App Shortcut** — "Convert a time in Time Converter" to Siri, or the row in
  Spotlight and in Shortcuts → App Shortcuts. No setup; it appears when the app
  installs. Needs no second target, which is why it shipped as its own slice.
- **Control Center control** — a "Convert a time" button the user adds to
  Control Center or the lock screen, from the `TimeConverterControls` extension.
  No home-screen real estate required.

Both run the same `ConvertATimeIntent`, and pressing either mid-session clears
whatever was typed: the button means *start* a conversion.

### QA: the launchers by hand

The App Shortcut and the control cannot be driven from a script, so they are
checked by hand. On a simulator (`scripts/run-ios.sh` installs the app *and* the
embedded extension) or a device:

1. **The control.** Settings → Control Center → scroll to "More Controls" (or
   pull down Control Center, long-press, "Add a Control") → search "Convert" →
   the `Convert a time` button with a globe-and-clock glyph should be listed
   under *Time Converter 3000* → add it. Tap it: the app comes forward with an
   empty field and the keyboard already up. Type `12pm ET in London` to confirm
   it is the ordinary app.
2. **The control, mid-session.** Open the app, type half a sentence, go back to
   the home screen, tap the control again — the field must come back **empty**,
   not half-typed.
3. **The App Shortcut.** Shortcuts app → *App Shortcuts* → *Time Converter 3000*
   → "Convert a time" should be listed; run it. Then pull down for Spotlight,
   type "Convert a time", and run the row. With Siri enabled on a device:
   "Convert a time in Time Converter".
4. **The URL route** (the only scriptable one, and the fallback path):

   ```bash
   xcrun simctl openurl booted timeconverter://convert
   ```

   iOS 26 shows an *"Open in TimeConverter?"* confirmation for any custom-scheme
   open from outside an app — tap **Open**. That prompt is a property of the URL
   route alone; the control and the App Shortcut never show it.

### QA: prefilling the input headlessly

DEBUG builds read a `-initialInput` launch argument (via `UserDefaults`, which
maps `-key value` arguments automatically), so a real conversion can be
screenshotted without typing. The argument is compiled out of Release builds.

The prefill bypasses the prompt debounce, so a launch-argument run renders its
conversion — or its prompt and chips — on the first frame rather than after a
pause.

```bash
scripts/run-mac.sh    # build once, then launch with a prefilled field:
open -n build/DerivedData/Build/Products/Debug/TimeConverter.app \
  --args -initialInput "12pm ET in London"
```

On the Mac the prefilled field is in the menu-bar dropdown (click the clock
glyph) or the ⌃⌥T panel; on iOS use `scripts/run-ios.sh` and
`xcrun simctl launch booted dev.thisolivier.timeconverter -initialInput "…"`.

Inputs that between them exercise the whole output area:

| `-initialInput` | Shows |
|---|---|
| `9:30 am New York to Lisbon` | A plain conversion, no chips |
| `9am CST to IST` | P4 chips; tapping twice converts |
| `12pm ET in Lodnon` | P5 did-you-mean chips |
| `12pm ET in London` | The expanded abbreviation echo |
| `9am Russia to London` | Ten chips, i.e. the wrapping layout |
| `7pm in London` | Local-zone defaulting: the *source* is `(local, …)` |
| `7pm east coast` | The same the other way round: the *target* is `(local, …)` |
| `7pm` | P2 — a time with no zone anywhere still prompts |

## Getting into the app on the Mac (menu bar + ⌃⌥T)

The Mac app **is** the menu bar: a small clock glyph, no Dock icon, no window.
Clicking the glyph drops down the converter; **⌃⌥T** from anywhere summons a
floating panel with the same converter in it. Pressing ⌃⌥T again while looking
at the panel puts it away; pressing it from another app brings the panel
forward rather than hiding it, because hiding there would make the hotkey look
broken (`SummonPolicy`, unit-tested).

Nothing is ever cleared on the Mac. On the Mac the app sits behind other
windows all day and ⌃⌥T is pressed to get *back* to a sentence mid-edit, so
clearing it would be destroying work — the opposite of the iOS Control Center
control, which means "start a conversion". That distinction is the tested value
`LaunchRequest.inputToStartFrom` in the core.

It is **⌃⌥T, not ⌃⌥Space**: Space already carries six system registrations
including ⌃⌥Space (input-source switching), while keycode 17 (T) carries none.

The whole thing lives in `TimeConverterMac/` as ordinary native code —
`MenuBarExtra(.window)`, `NSPanel`, and Carbon `RegisterEventHotKey`, which
needs no permission because the WindowServer delivers only the one pre-declared
chord. The retired Catalyst approach (backlog item 12a) had to load a macOS-SDK
`.bundle` into the Catalyst process to reach any of that, along with an `@objc`
hosting protocol whose silent mis-cast was the sharpest trap in the design; all
of it is gone, and `GlobalHotKey.swift` ported across unchanged. The view layer
is a deliberate placeholder — `docs/ux-v1-proposal.md` has a translucent
Spotlight-style modal for the design sprint.

### QA: the menu bar headlessly

```bash
scripts/qa-menubar.sh
```

Eleven steps, all headless bar the last: hotkey-collision snapshot via
`CopySymbolicHotKeys()`, a `platform MACOS` check on the binary and
`LSUIElement` on the built plist, the launch log line naming what actually came
up, single-instance plus RSS, a second instance via `open -n` being harmless,
and re-registration after both a quit and a `kill -9`. It leaves nothing
running.

### QA: the 10-second manual check (the one thing a script cannot do)

`RegisterEventHotKey` returning `noErr` is **not** proof that a press fires —
it returns `noErr` for combos the system already owns too — and synthetic
keystroke injection is TCC-blocked, so a literal keypress has to be a human.
On an unlocked screen:

```bash
scripts/run-mac.sh
```

Then: **click another app, and press ⌃⌥T.**

Expect, in order:

1. A small floating "Time Converter" panel appears, centred, field focused.
2. Type half a sentence, press ⌃⌥T again while looking at it — it hides. Press
   once more — it comes back with the half-typed text **still there**.
3. Clicking the clock glyph opens the dropdown, with its own focused field.
4. "Quit Time Converter" in the dropdown — the glyph disappears.

Every press logs a line, which is what separates "the keystroke never arrived"
from "the summon failed":

```bash
log show --predicate 'subsystem == "dev.thisolivier.timeconverter"' \
  --last 2m --style compact
```

Nothing logged on a press means the keystroke did not reach the process at all
— suspect screen-share key forwarding, or another process holding ⌃⌥T. A
`hotkey received` line with no panel is a real bug.
