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

`scripts/ship.sh <build>` archives, exports and uploads to TestFlight. Release
signing is **manual**, against named provisioning profiles — the app's is
`TimeConverter App Store`.

> **⚠️ `ship.sh` cannot complete right now.** Since backlog item 11 the app
> embeds a second target, the `TimeConverterControls` extension, and an
> extension needs its *own* App ID and its *own* distribution profile — the
> app's profile cannot cover it. The build expects a profile named
> **`TimeConverter Controls App Store`**, which does not exist yet, so the run
> fails at **step 3/6 (archive)** while signing the extension (and would fail
> again at step 4/6, export). Everything else — Debug builds, both test lanes,
> `run-ios.sh`, `run-mac.sh` — works without it, because Debug signs ad-hoc with
> no team.
>
> Olivier, before the next ship, in the Apple Developer portal (team
> `CNHB9B5GX6`):
>
> 1. **Identifiers → App IDs → +** → App → Description
>    "Time Converter 3000 Controls", Bundle ID **explicit**
>    `dev.thisolivier.timeconverter.controls`. No capabilities needed.
> 2. **Profiles → +** → *App Store Connect* (distribution) → select that App ID
>    → certificate **Apple Distribution** (the team's existing one) → name it
>    exactly **`TimeConverter Controls App Store`**.
> 3. Download it and double-click, or drop it in
>    `~/Library/MobileDevice/Provisioning Profiles/`, on this build machine —
>    the same place `TimeConverter App Store` lives.
> 4. Run `scripts/ship.sh <build> --skip-upload` once to prove archive and
>    export both pass before a real upload.
>
> No change to `project.yml` or `ExportOptions.plist` is needed afterwards; both
> already name the profile.

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

Four inputs that between them exercise the whole output area:

| `-initialInput` | Shows |
|---|---|
| `9:30 am New York to Lisbon` | A plain conversion, no chips |
| `9am CST to IST` | P4 chips; tapping twice converts |
| `12pm ET in Lodnon` | P5 did-you-mean chips |
| `12pm ET in London` | The expanded abbreviation echo |
| `9am Russia to London` | Ten chips, i.e. the wrapping layout |

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

**This is a local-only feature, by design.** It lives in
`TimeConverterMenuBar/`, a macOS-SDK bundle loaded out of `Contents/PlugIns` at
launch — the only way to reach `NSStatusItem` and Carbon's
`RegisterEventHotKey` from Catalyst at all. `platformFilter: macOS` keeps it out
of iOS builds entirely, so the shipped `.ipa` has no trace of it and
`scripts/ship.sh` is unaffected. Loading is optional at every step: if the
bundle is missing or refuses to load, the app logs one line and runs normally.
Apple DTS has twice called this architecture unsupported for distribution and
there is no Mac delivery lane yet (backlog item 12b), so nothing here is
expected to reach a user. See `TimeConverter/MenuBar/readme.md`,
`TimeConverterMenuBar/readme.md` and `docs/menu-bar-poc-plan.md`.

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
