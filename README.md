# TimeConverter

A small iOS/macOS app (SwiftUI) for freeform timezone conversion: type
something like `12pm ET in London` or `06:34 Portugal in PST` and see the
converted time.

**Two native shells over one shared core** (backlog item 16). `TimeConverterCore`
is a local Swift package holding the parser, the presenter and every rule —
plus, since item 20, a second product `TimeConverterUI` holding the SwiftUI
design layer the two platforms share. The iOS app is a window, and the Mac app
is a menu-bar utility with a ⌃⌥T global hotkey and no persistent window. Mac Catalyst is retired — the platforms want
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
| `TimeConverter` | iOS | the iOS app + the Controls extension; `TimeConverterTests` + both of the package's test targets, on the simulator |
| `TimeConverterMac` | macOS | the native menu-bar app; `TimeConverterMacTests` + the same two package test targets, natively |

```bash
scripts/test.sh                 # unit tests, iOS simulator (305 tests)
scripts/test.sh --platform mac  # unit tests, native macOS (328 tests)
scripts/test.sh --platform all  # both lanes
scripts/test.sh PromptTests     # one core suite (bare names mean the core)
scripts/run-ios.sh              # build, install and launch on a simulator
scripts/run-mac.sh              # build and launch the native Mac menu-bar app
scripts/qa-menubar.sh           # Mac-only: QA the menu bar and ⌃⌥T (Debug)
scripts/render-glass.sh         # Mac-only: PNGs of the glass panel, no screen
cd TimeConverterCore && swift test   # the core alone, fastest loop
scripts/test-android.sh         # Android: JVM tests incl. the shared-fixture contract
scripts/run-android.sh --input "12pm ET in London" --screenshot shot.png  # headless emulator
scripts/run-android.sh --release   # same, with the signed R8-shrunk release APK
scripts/setup-android-signing.sh   # one-off: the Android release key (back it up!)
scripts/ship-android.sh <N> [--dry-run]   # Android: signed APK → GitHub Release
scripts/regenerate-fixtures.sh  # rewrite fixtures/conversion-cases.json from the Swift core
```

The shared core is deliberately tested **twice**, once per platform, which is
why the two lanes overlap by 298 tests. Run `--platform all` before shipping
anything that touches parsing, the presenter or startup wiring — in the sibling
music projects the Mac build broke twice while the iOS lane stayed green.

## Android

A third shell, `TimeConverterAndroid/` (Kotlin + Jetpack Compose, phones;
sideloaded via GitHub Releases + Obtainium, not Google Play), built the same way as the other two: a thin UI over a core that
holds every rule. There is no shared runtime with the Swift core — instead
**Release parity.** A change to the shared core ships to all three lanes at
the same build number. Every ship script runs `scripts/lib/parity-gate.sh`
before building: the Swift core suite (which fails when
`fixtures/conversion-cases.json` is stale) and, on Android, a check that every
shared-fixture class ran with nothing skipped or `@Ignore`d. After a real
upload each lane appends to `docs/releases.md` and prints which other lanes
are behind on core changes.

**`fixtures/conversion-cases.json`** is generated from the Swift core and
asserted by both test suites, so the two parsers are held to one behaviour.
The engine is ported and passes that contract; the parser port is next
(`docs/android-plan.md`; distribution without Play: `docs/android-distribution.md`). Toolchain, scripts and the headless-emulator QA loop
are described in `TimeConverterAndroid/readme.md`; `scripts/setup-android.sh`
reproduces the machine setup.

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
| status | **working** | **working** — first native build 7 |

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

> The Mac lane's portal setup (profile + Mac Installer Distribution
> certificate) is recorded under **"macOS train"** in
> `docs/testflight-setup-checklist.md`. If signing ever changes, run
> `scripts/ship-mac.sh --validate-only` first: it asks App Store Connect's
> validator for a verdict **without delivering anything and without consuming
> a build number** — macOS build numbers are unrecoverable.

### Which lanes to ship — the both-lanes rule

**Any change under `TimeConverterCore/` ships on both lanes**, in the same
release, one after the other:

```
scripts/test.sh --platform all      # both must pass
scripts/ship.sh <N>                 # iOS
scripts/ship-mac.sh <N+1>           # macOS — build numbers are shared, so +1
```

The core package (parser, conversion engine, presenter, shared design layer)
is compiled into *both* apps, so a feature there is a feature on both
platforms. Shipping only one lane silently leaves the other behind — that is
how item 22 (bare zone = now) reached iOS build 12 but not the Mac. Only a
change confined to one shell (`TimeConverter/`, `TimeConverterControls/` →
iOS only; `TimeConverterMac/` → Mac only) may ship on a single lane. Record
both in the ship commit, e.g. `iOS build 13 + Mac build 14 shipped (…)`.

To check whether a lane is behind, compare the last ship commit for each
(`git log --oneline | grep shipped`) against `git log -- TimeConverterCore`.

### Android lane

`scripts/ship-android.sh <N>` builds the signed release APK, checks it is
signed by the key from `scripts/setup-android-signing.sh`, smoke-tests it on
the emulator and publishes it as GitHub Release `android-<versionName>` (e.g.
`android-0.1.0.17`), where Obtainium on the phone picks it up. It shares the
build number with the Apple lanes: new code takes the next number, and
re-shipping a number Apple just used for the same code is allowed. Ship commit: `Android build <N> shipped (…)`. Details:
`TimeConverterAndroid/readme.md`; the partner's install steps:
`docs/android-install.md`.

## Layout

- `TimeConverterCore/` — **the local SPM package, now two products.**
  `TimeConverterCore` is everything that is not a view: `Parsing/` is the
  headless parser and conversion engine, `Presentation/` is the presenter plus
  the display driver that owns *when* the output changes, `Launch/` is the
  launch-request logic and the DEBUG prefill, and
  `Resources/fallback-cities.json` is reached through `Bundle.module`.
  `Sources/TimeConverterUI/` is the shared SwiftUI design layer (item 20): the
  poster and glass colour tokens, the glass panel's measurements and chrome,
  the typography helpers, the arrow shapes, the chip flow layout and
  `ConversionPairView`, the FROM/TO pair the iPad and Mac designs both draw. Between them `Tests/` holds 298 of the repo's tests. See
  `TimeConverterCore/readme.md`,
  `TimeConverterCore/Sources/TimeConverterUI/readme.md` and
  `TimeConverterCore/Sources/TimeConverterCore/Parsing/readme.md`
- `TimeConverter/` — the **iOS** shell. `ContentView.swift` lays out the poster
  and owns the behaviour; `Poster/` is the design's visual language (see
  `TimeConverter/Poster/readme.md`); `PromptChipRow.swift` renders the
  correction chips; `InputFocusPolicy.swift` decides when the field takes
  focus; `Launchers/` is the App Shortcut and the intent (see
  `TimeConverter/Launchers/readme.md`)
- `TimeConverterMac/` — the **macOS** shell: `MenuBarExtra`, the summoned glass
  panel, ⌃⌥T (see `TimeConverterMac/readme.md`)
- `TimeConverterControls/` — the Control Center widget extension, iOS-only (see
  `TimeConverterControls/readme.md`)
- `TimeConverterTests/`, `TimeConverterMacTests/` — each shell's own tests, thin
  by design (Swift Testing)
- `TimeConverterAndroid/` — the **Android** shell and its Kotlin core (see
  `TimeConverterAndroid/readme.md`)
- `fixtures/` — the generated cross-platform behaviour fixtures (see
  `fixtures/readme.md`)
- `docs/` — backlog (`docs/backlog.md`) and specs
- `scripts/` — build/run/test helpers

Note: the targets' `sources` globs copy non-Swift files into the bundle,
flattened, so every module `readme.md` is excluded in `project.yml` — without
that exclude two readmes in different modules collide at build time. The
package does the same thing with `exclude:` in `Package.swift`, where an
unhandled `readme.md` would otherwise be warned about and copied. The iOS view
layer has no module of its own and is documented below instead.

## UI layer

This section describes the **iOS** shell. The Mac shell has its own visual
language since item 20 phase B — the glass panel of design page 3, documented
in `TimeConverterMac/readme.md` — but drives the identical
`ConverterDisplayDriver`, so every rule below (debounce, chips, instant
results) holds there too. The two shells share the design *layer*
(`TimeConverterUI`) and disagree only about which of its two palettes they
wear.

Since backlog item 18 the iOS shell wears Olivier's design
(`docs/design/Time Converter.{pdf,html}`): a retro print poster — cream paper
`#EBD3A9`, ink `#141210`, one rust accent `#B5391F`, giant condensed
`TIME CONVERTER`, letterspaced uppercase labels, an outlined input box with the
parsed source echoed *inside* it, a rule-and-arrow separator, the result at
poster scale, and a footer sentence. System fonts only — Anton renders as SF
Compressed Black, JetBrains Mono as SF Mono, and nothing is bundled. Dark mode
is a straight inversion of the same three tokens. The details, including why
the arrow is a hand-drawn `Path` and where the palette was adjusted for
contrast, are in `TimeConverter/Poster/readme.md`.

Two sprints have refined that band since. **Item 21** replaced the design's
bare `UTC−3` under the big time with the *zone*, keyed on how the target was
asked for: name a place and the header stays `IN SÃO PAULO` over
`BRASILIA STANDARD TIME (SÃO PAULO)`; name a code and the header expands it,
`IN ET (EASTERN TIME)` over `NEW YORK, TORONTO`. The box echo lost its offset
too (`Lisbon · 8:00 PM`). Disambiguation chips kept theirs, because there an
offset is the whole basis for choosing. **Item 19** added the keyboard
choreography: with something typed and the keyboard up, the title and the rule
under it collapse away and the numerals step down, so the input box through the
footer stay above the keyboard. An empty field keeps the full poster. The
keyboard is dismissible by dragging the poster or tapping anywhere
non-interactive.

**Neither sprint changed any behaviour below the surface.** Everything below is
as it was.

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
  `7:00 pm Los Angeles (local, UTC-8) → 3:00 am London (UTC+0) +1d`), and
  bare-zone input, where a lone `ET` converts the device's *current* clock,
  minutes included (`3:42 pm Los Angeles (local, UTC-8) → 6:42 pm Eastern Time
  (New York, Toronto, UTC-5)`).
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
- **Every conversion carries a footer sentence** (spec amendment 2026-10-23,
  re-worded by the iPad/Mac designs in item 20):
  `São Paulo is 4 hours behind Lisbon.` /
  `London is 3 hours ahead of New York.` /
  `Madrid is the same time as Paris.` It is computed in the core's
  `ConversionEngine` from the two offsets **at the resolved instant**, so it
  follows daylight saving on the day asked about; half- and quarter-hour zones
  read decimally (`Kolkata is 5.5 hours ahead of London.`). The sentence names
  its **target** because the iPad and Mac draw two times side by side, where a
  bare `4 hours behind Lisbon.` is a riddle about which column it describes;
  the iPhone adopted the same wording so there is one sentence and one
  implementation.
- **Where the design and a feature disagreed, the feature won and got
  restyled.** The mockup draws only the happy path and has no chips in it, so
  the prompts and their tap-to-replace chips are set in the design's own
  vocabulary — letterspaced rust label, rust mono body, square outlined chips
  that invert when pressed — rather than dropped. Prompt *copy* is still the
  verbose multi-line spec wording, and P4 still lists its candidates inline
  above the chips; only the setting changed.

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
| `8pm Lisbon in Sao Paulo` | The design's own example, footer and all |
| `9:30 am New York to Lisbon` | A plain conversion, no chips |
| `9:30am London in India` | A half-hour zone: `Kolkata is 4.5 hours ahead of London.` (the offset still shows in the Mac echo) |
| `11pm New York to Tokyo` | The day rollover, which rides the zone line |
| `9am CST to IST` | P4 chips; tapping twice converts |
| `12pm ET in Lodnon` | P5 did-you-mean chips |
| `12pm ET in London` | The expanded abbreviation echo |
| `9am Russia to London` | Ten chips, i.e. the wrapping layout |
| `7pm in London` | Local-zone defaulting: the *source* is `(local, …)` |
| `7pm east coast` | The same the other way round: the *target* is `(local, …)` |
| `7pm` | P2 — a time with no zone anywhere still prompts |
| `8pm Lisbon in ET` | The abbreviation header: `IN ET (EASTERN TIME)` over `NEW YORK, TORONTO` |
| `12pm London to UTC` | The one zone with no sub-line at all — GMT and UTC are the datum, not a place |
| `ET` | Bare zone (item 22): the clock **right now** in ET, source `(local, …)` with the current minutes |
| `Tokyo` | The same with a city token, usually with `NEXT DAY` on the sub-line |
| `CST` | A bare ambiguous token — P4 chips; the tap rewrites the whole field |
| `Lodnon` | A bare unknown token — P5 did-you-mean chips, `London?` rewriting the whole field |
| `12` | Still P1: digits read as a half-typed time, not as a zone nobody recognises |

### QA: the collapsed keyboard layout headlessly (iOS)

With something typed and the keyboard up, the title and the rule under it
collapse away and the result numerals step down to 92pt, so the input box
through the footer stay above the keyboard (backlog item 19). The simulator
usually has its software keyboard switched off, which means that state is
unreachable from a script — so DEBUG builds also read **`-forceCompact 1`**,
which makes the app behave as though the keyboard were up.

```bash
scripts/run-ios.sh    # build, install, launch; then:
xcrun simctl launch booted dev.thisolivier.timeconverter \
  -initialInput "8pm Lisbon in Sao Paulo" -forceCompact 1
```

It forces the *input* to the layout rule, not the answer, so it has to be
paired with `-initialInput` — on an empty field the rule correctly keeps the
full poster, keyboard or no keyboard. Without `-forceCompact`, `-initialInput`
still renders the full un-collapsed poster exactly as it always did.

To see the real thing rather than the forced one, turn the simulator's software
keyboard on (Simulator → I/O → Keyboard → uncheck *Connect Hardware Keyboard*,
or `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool
false` before booting) and launch with `-initialInput` alone: item 10's
autofocus raises the keyboard and the collapse animates on arrival.

### Favourites and the Clocks tab (items 30–31)

Taps cannot be scripted, so DEBUG builds also read these (ignored in Release;
see `LaunchArguments+Clocks.swift`):

| Argument | Effect |
|---|---|
| `-favourites "London,ET,Tokyo"` | **Replaces** the stored favourites with what starring the target of `12pm in <zone>` stores, per zone. `""` clears them. |
| `-selectedTab clocks` | Opens on the Clocks tab. |
| `-clockOffsetDays 3` / `m3` | Starts the day stepper there (`m` for minus: a bare `-3` reads as a flag). |
| `-clockOffsetMinutes 1140` | Starts the slider there (clamped to ±1440, snapped to 15). |

```
xcrun simctl launch booted dev.thisolivier.timeconverter \
  -favourites "London,ET,Tokyo" -selectedTab clocks -clockOffsetMinutes 1140
```

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
of it is gone, and `GlobalHotKey.swift` ported across unchanged.

Since item 20 phase B the summoned thing is **the glass panel of design page
3**: 740pt wide, frosted over the desktop, 30pt corners, no title bar and no
close button, with the typed line at the top, the side-by-side FROM/TO pair in
the middle and the target-named footer at the bottom. The menu-bar dropdown is
the same view at 400pt, where the pair stacks vertically because it measurably
does not fit side by side. The frosting is an `NSVisualEffectView`
(`.hudWindow`, behind-window) and the shadow is the window's own — the mapping
from the design's CSS to what actually draws each declaration is a table in
`TimeConverterUI/Components/GlassPanelSurface.swift`.

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

1. The glass panel appears, centred — frosted, chromeless, 740pt wide. **Type
   without touching the mouse** — the characters land in the big mono line at
   the top (backlog item 17; the `@FocusState` write is the one part of that
   fix no test can reach). The desktop must be visibly blurred *through* the
   panel and must change as you drag it across different wallpaper; that is
   the behind-window material, and it is the one thing no offscreen render can
   prove.
2. Press ⌃⌥T again while looking at it — it hides. Press once more — it comes
   back with the half-typed text **still there**, and typing still goes
   straight in.
3. Click a *third* app so the panel is behind it, press ⌃⌥T, and type again.
   This is the case window state alone cannot detect, and the one
   `SummonFocusRequests` exists for.
4. Clicking the clock glyph opens the dropdown, also ready to type — the same
   design at 400pt, with the pair stacked above and below a down arrow.
5. "Quit" on the footer line — the glyph disappears.

For the layout and the type without a screen at all, `scripts/render-glass.sh`
draws the real views into PNGs in both appearances. It cannot show the
frosting — an offscreen pass has no window and therefore no desktop to blur —
and says so.

Every press logs a line, which is what separates "the keystroke never arrived"
from "the summon failed":

```bash
log show --predicate 'subsystem == "dev.thisolivier.timeconverter"' \
  --last 2m --style compact
```

Nothing logged on a press means the keystroke did not reach the process at all
— suspect screen-share key forwarding, or another process holding ⌃⌥T. A
`hotkey received` line with no panel is a real bug.
