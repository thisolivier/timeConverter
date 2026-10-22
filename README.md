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
scripts/qa-menubar.sh           # Mac-only: QA the menu bar and ⌃⌥T (Debug)
```

Run `--platform all` before shipping anything that touches startup wiring or
storage — in the sibling music projects the Mac build broke twice while the
iOS lane stayed green.

## Shipping

Two lanes into the **same** App Store Connect record (app `6825044484`), one per
platform train. Release signing is **manual** in both, against named
provisioning profiles.

| | iOS | macOS (Mac Catalyst) |
|---|---|---|
| | `scripts/ship.sh <build>` | `scripts/ship-mac.sh <build>` |
| profiles | `TimeConverter App Store`, `TimeConverter Controls App Store` | `TimeConverter Mac App Store`, `TimeConverter Controls Mac App Store` |
| product | `.ipa` → `altool -t ios` | `.pkg` → `altool -t macos` |
| status | **working** — build 5 is VALID | **blocked on the portal** (below) |

The build number comes from `project.yml`'s `CURRENT_PROJECT_VERSION` via
`scripts/lib/version.sh`, shared by both scripts on purpose: macOS requires
`CFBundleVersion` to increase monotonically across *all* trains, so the two
lanes cannot be allowed to drift.

### Why the Mac needs its own lane at all

An iOS TestFlight build does install and run on an Apple silicon Mac — but as
"iPhone and iPad app on Mac", i.e. the *iOS* binary in the iOS runtime, not the
Catalyst product. Nothing built against the macOS SDK can load there, so the
menu-bar bundle and ⌃⌥T (backlog item 12a) cannot ride the iOS lane under any
configuration. `ship-mac.sh` archives the real Catalyst product, with
`Contents/PlugIns` and both embedded bundles intact.

> **⚠️ `ship-mac.sh` cannot complete yet** — it needs two macOS provisioning
> profiles and a Mac Installer Distribution certificate that do not exist. It
> stops in **preflight (step 2/7)**, before touching the build number, and
> prints the portal steps. The full list is under **"macOS train"** in
> `docs/testflight-setup-checklist.md`. Nothing else is affected: `ship.sh`,
> Debug builds, both test lanes, `run-ios.sh` and `run-mac.sh` all work, because
> Debug signs ad-hoc with no team and the macOS signing settings are scoped to
> Release *and* the macOS SDK.
>
> Once the profiles are installed, the first command to run is
> `scripts/ship-mac.sh --validate-only`: it archives, exports and asks App Store
> Connect's validator for a verdict **without delivering anything and without
> consuming a build number**. That is how we find out whether ingestion accepts
> a Catalyst app with a macOS-SDK `.bundle` embedded in it — a question with no
> precedent on the public record either way.

## Layout

- `TimeConverter/` — app source. `ContentView.swift` is the whole interface;
  `ConverterPresenter.swift` turns parse output into display values;
  `ConverterDisplayDriver.swift` owns *when* the output area changes;
  `PromptChipRow.swift` renders the correction chips; `Parsing/` is the
  headless parser and conversion engine (see
  `TimeConverter/Parsing/readme.md`); `Launchers/` is the App Shortcut, the
  intent and the URL route (see `TimeConverter/Launchers/readme.md`)
- `TimeConverterControls/` — the Control Center widget extension (see
  `TimeConverterControls/readme.md`)
- `TimeConverterMenuBar/` — the Mac-only menu-bar bundle, a macOS-SDK target
  excluded from iOS builds entirely (see `TimeConverterMenuBar/readme.md` and
  `TimeConverter/MenuBar/readme.md`)
- `TimeConverterTests/` — test suite (Swift Testing)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers

Note: the targets' `sources` globs copy non-Swift files into the bundle,
flattened, so every module `readme.md` is excluded in `project.yml` — without
that exclude two readmes in different modules collide at build time. The UI
layer has no module of its own and is documented below instead.

## UI layer

Still deliberately minimal: one text field, one output area, content
constrained to ~480pt so the Catalyst window reads as a small utility.

**The guiding rule is that the typed sentence is the single source of truth, on
every platform.** Every interaction edits that sentence rather than introducing
parallel state — which is why a correction chip rewrites a span of the input
string and lets the ordinary re-parse take it from there, instead of holding a
selection somewhere.

- **The UI is the only thing that knows what time it is, or where it is.**
  `ContentView` calls `Date()` and reads `TimeZone.current`, and passes both
  down; the driver, presenter, parser and conversion engine all take them as
  parameters. That single injection point is what keeps everything below the
  view pure and testable — including local-zone defaulting, where the device
  zone fills in a side the user didn't name (`7pm in London` →
  `7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d`).
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
  `.inactive` (don't), which is the case that matters on Catalyst. A launcher
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
open -n build/DerivedData/Build/Products/Debug-maccatalyst/TimeConverter.app \
  --args -initialInput "12pm ET in London"
```

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

The Catalyst app puts a small clock glyph in the menu bar and registers **⌃⌥T**
as a global hotkey. Both do the same thing: bring TimeConverter forward with the
field focused and **whatever was typed still in it**. That is the one place the
Mac deliberately disagrees with the iOS launchers — on the Mac the app sits
behind other windows all day and ⌃⌥T is pressed to get *back* to a sentence
mid-edit, so clearing it would be destroying work. (Internally that is
`LaunchRequest.summonWithoutReset` rather than `.startFreshConversion`.)

It is **⌃⌥T, not ⌃⌥Space**: Space already carries six system registrations
including ⌃⌥Space (input-source switching), while keycode 17 (T) carries none.

It lives in `TimeConverterMenuBar/`, a macOS-SDK bundle loaded out of
`Contents/PlugIns` at launch — the only way to reach `NSStatusItem` and Carbon's
`RegisterEventHotKey` from Catalyst at all. `platformFilter: macOS` keeps it out
of iOS builds entirely, so the shipped `.ipa` has no trace of it and
`scripts/ship.sh` is unaffected. Loading is optional at every step: if the
bundle is missing or refuses to load, the app logs one line and runs normally.

**Whether it can ever reach a user is still open.** `scripts/ship-mac.sh`
(backlog item 12b) is the lane that would carry it, and the local half of that
lane is built and verified: the Catalyst archive contains the bundle, the App
Sandbox the Mac App Store demands is wired in for Release only, and the bundle
is signed the one way a loadable plug-in may be — no entitlements, no embedded
profile. What is not known is Apple's answer. Ingestion has no public precedent
either way, and DTS has called the architecture unsupported three times across
2024–2025, so `ship-mac.sh --validate-only` exists to ask without spending a
build number. See `TimeConverter/MenuBar/readme.md`,
`TimeConverterMenuBar/readme.md`, `docs/menu-bar-poc-plan.md` §3 and the
"macOS train" section of `docs/testflight-setup-checklist.md`.

### QA: the menu bar headlessly

```bash
scripts/qa-menubar.sh
```

Twelve steps, all headless bar the last: hotkey-collision snapshot via
`CopySymbolicHotKeys()`, bundle placement and `platform MACOS`/`MACCATALYST`
checks, the load and registration log line, single-instance plus RSS, a second
instance via `open -n` being harmless, re-registration after both a quit and a
`kill -9`, and the app still running with the bundle moved out of `PlugIns`. It
leaves nothing running.

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

1. TimeConverter comes forward with the input field focused.
2. Type half a sentence, click another app, press ⌃⌥T again — the half-typed
   text is **still there** (the Control Center control, by contrast, clears it).
3. Clicking the clock glyph in the menu bar does exactly the same as the
   keypress.
4. ⌘Q — the glyph disappears from the menu bar.

If step 1 fails while `scripts/qa-menubar.sh` passes, the registration is being
shared or shadowed by another process rather than broken: quit anything that
grabs global hotkeys and retry.
