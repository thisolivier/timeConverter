# TimeConverterMac

The native macOS app: a menu-bar utility, not a window app. A clock glyph in
the menu bar whose dropdown is the converter, plus ⌃⌥T from anywhere to summon
a floating panel. No Dock icon, no persistent window, nothing to close.

This is the Mac story since backlog item 16, and it **replaces** Mac Catalyst
rather than sitting beside it. The retired approach (item 12a) was a macOS-SDK
`.bundle` loaded into the Catalyst process at runtime, because Catalyst could
reach neither `MenuBarExtra` nor `NSStatusItem` nor Carbon. All three are
ordinary API in a native target, so the bundle, its `@objc` hosting protocol,
its loader and its whole class of invisible failures are gone. `GlobalHotKey.swift`
ported across unchanged, which is the proof: Carbon was never the hard part.

## Working patterns

- **The shell is thin and the core is shared.** Everything below the view layer
  — parsing, the presenter, the 600 ms prompt debounce, the tap-to-replace
  chips — is the `TimeConverterCore` package, the same build the iOS app
  consumes. There is no forked model and no second copy of any rule. The
  platforms differ in *access*, never in behaviour.
- **The view layer is the design now** (backlog item 20, phase B). The
  placeholder — a plain field, a plain output area, an ordinary titled
  `NSPanel` — is gone, replaced by page 3 of
  `docs/design/Time Converter-selection.pdf`: a 740pt frosted panel with the
  typed line at the top, the `FROM`/`TO` pair in the middle and the
  target-named footer at the bottom. Everything drawn comes from
  `TimeConverterUI`; what is left here is state and window plumbing.
- **One design, two containers.** The panel and the dropdown are the *same*
  view, parameterised by `GlassPresentation`, which carries exactly three
  differences: how wide, who supplies the glass, and whether it has to say how
  to dismiss itself. Nothing else branches. That is working assumption 3 of
  the sprint plan made structural.
- **The dropdown stacks because the pair does not fit, not because it was
  told to.** A menu-bar popover is around 400pt; the side-by-side pair needs
  about 600 at the design's size step and about 440 at the compact one. So
  `GlassPanelMetrics` asks `ConversionPairScale.largestFittingSideBySide(in:)`
  and gets `nil`, and the pair turns vertical with the down arrow between the
  two columns. Drawing it side by side at 400pt would mean
  `minimumScaleFactor` shrinking 124pt numerals to caption size — not a
  smaller poster, a destroyed one.
- **Where the system has a real equivalent, the system wins.** The frosting is
  an `NSVisualEffectView` at `.hudWindow` with `.behindWindow` blending — the
  only thing on macOS that samples the actual desktop — and it supplies *both*
  halves of the design's CSS (the blur and the white veil), because an AppKit
  material is blur plus tint while `backdrop-filter` is blur alone; stacking
  the design's extra 42% on top produced a panel you could not see through.
  The shadow is the window's own, because a transparent `NSWindow` with
  `hasShadow` computes one from the content's alpha and drawing it by hand
  would have meant `.compositingGroup()`, which takes the vibrancy with it.
  The full declaration-by-declaration mapping is in `GlassPanelSurface.swift`.
- **The panel is as tall as its contents, and saying so out loud is
  load-bearing.** `NSHostingController.sizingOptions = .preferredContentSize`
  is set explicitly rather than left to the default: without it the window is
  measured once, before `onAppear` has run — which is the empty hint — and
  never grows again, so an actual conversion's 124pt numerals get squeezed
  into the height of a one-line placeholder. Measured, not theorised: the
  panel came up 740×279 for every state until that line existed, and now comes
  up 279 empty, 314 for a prompt and 444 for a conversion. AppKit resizes a
  window's content from the top-left, so it grows downward rather than
  appearing to jump.
- **The panel has no chrome, so it has to say how to leave.** No title bar, no
  close button, not resizable (a fixed internal proportion is the design).
  `GlassFooterText` therefore puts `⌃⌥T hides this panel · esc dismisses it`
  on the footer line whenever there is no conversion sentence to put there —
  which is the only state in which someone would need it.
- **Prompts are drawn in the panel's vocabulary, not the poster's.** The
  iPhone sets its prompts in rust. Glass has no accent — page 3's single
  loudest decision is that the arrow is *grey* rather than rust — so the
  hierarchy is built out of contrast instead: a quiet letterspaced caption
  over a full-strength message, with translucent outlined chips beneath.
- **A panel, not a programmatically opened dropdown.** SwiftUI exposes no way
  to open a `MenuBarExtra` from code — doing it anyway means synthesising a
  click on an `NSStatusItem` SwiftUI never hands you. Thirty lines of `NSPanel`
  is less code and less fragile for something the design will replace.
- **A toggle only toggles when you can already see it.** `SummonPolicy` is the
  one judgement call in the summon path, extracted so it can be unit-tested:
  visible *and* frontmost → hide; visible but another app is active → bring
  forward, because hiding there makes the hotkey look broken.
- **A summon lands the cursor in the field** (backlog item 17, user-reported
  from real use). `@FocusState` only takes hold once the hosting view's window
  is key and SwiftUI has installed its responder chain, and neither has
  necessarily happened when `onAppear` runs on a window AppKit is still
  ordering front — so a single write landed *usually*, which is the complaint.
  The fix is two triggers and a short ladder: `controlActiveState` turning
  `.key` covers the dropdown, the panel, and every re-raise;
  `SummonFocusRequests` (a counter, because `true → true` is not an `onChange`)
  covers the press that reaches a panel which is already key. Each trigger
  writes the focus three times over 200 ms, because the attempt that works
  cannot be predicted and the ones that follow it are no-ops. The ladder is
  deliberately finite — an endless retry would fight the user for the cursor.
- **Carbon for the hotkey, because it needs no permission.**
  `RegisterEventHotKey` has the WindowServer deliver one pre-declared chord, so
  the process never sees the keystream and there is nothing for TCC to protect.
  `CGEventTap` and `NSEvent.addGlobalMonitorForEvents` both need Input
  Monitoring and fail by reporting success and then silently never firing. The
  API is old, not deprecated, and works from a sandboxed App Store app with no
  entitlement.
- **Everything the menu bar does is logged, and nothing it does is fatal.** One
  `menu bar ready: … — status item + ⌃⌥T` line at launch naming what *actually*
  came up, and one `hotkey received` line per press. That pair is what
  distinguishes "the keystroke never arrived" (nothing logged — suspect
  screen-share key forwarding) from "the summon failed" (logged, no panel). A
  hotkey another app holds exclusively costs a log line, never the app.
- **Launch registers the hotkey, not first use.** It lives on
  `applicationDidFinishLaunching` via `@NSApplicationDelegateAdaptor`; a view's
  `onAppear` would not fire until the dropdown was first opened, by which point
  the user has already pressed ⌃⌥T and concluded it is broken.

## Components

- `TimeConverterMacApp.swift` — `@main`. The `MenuBarExtra(.window)` scene and
  `TimeConverterMacDelegate`, which registers ⌃⌥T and pins `.accessory`
  activation policy.
- `MenuBarConverterView.swift` — the state the layout refuses to own: the typed
  sentence, the display driver, and item 17's focus choreography. One view for
  both containers, parameterised by `GlassPresentation`.
- `GlassConverterLayout.swift` — page 3 assembled: typed line, hairline,
  conversion, hairline, footer. Stateless, so the live panel, the live dropdown
  and the offscreen renderer all drive the same thing. Plus `GlassInputField`
  (the live line) and `GlassInputEcho` (the same line for `ImageRenderer`,
  which cannot rasterise a `TextField`).
- `GlassPanelLayout.swift` — the two decisions that are not drawing:
  `GlassPresentation` (which container, and what follows), `GlassResultSection`
  (which section a display state routes to) and `GlassFooterText` (the
  sentence, or the dismissal hint). View-free, and a member of the test target.
- `GlassPromptView.swift` — prompts and tap-to-replace chips on glass.
- `PanelSummoner.swift` — owns the hotkey and the chromeless, transparent,
  content-sized `NSPanel`, and logs what came up.
- `MacAppearanceOverride.swift` — `-appearance dark|light`, DEBUG only, so both
  halves of the design can be looked at without changing the whole machine.
  (`-summonOnLaunch 1`, on `PanelSummoner`, opens the panel without a keypress
  — the only way anything automated ever reaches `makePanel`, since synthetic
  keystrokes are TCC-blocked. It is how the content-sizing bug below was
  found.)
- `GlassPanelRenderer.swift` — `-renderGlass <dir>`, DEBUG only. Draws the real
  views into PNGs and quits; see `scripts/render-glass.sh`.
- `SummonPolicy.swift` — the show/hide rule and whether it also takes the
  keyboard, plus `SummonFocusRequests` and `SummonFocusLadder` (item 17) and
  `MacMenuBarLog`, the log identity the two shell scripts filter on. These live
  together because they are all members of the test target, and because they
  are the same question: what a press of ⌃⌥T should actually do.
- `GlobalHotKey.swift` — ⌃⌥T via Carbon. Ported verbatim from the retired
  bundle.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its load-bearing key is `LSUIElement`.
- `TimeConverter-macOS.entitlements` — one line,
  `com.apple.security.app-sandbox`. No network entitlement (the app makes no
  requests), no file access (the only file read is in its own bundle), and
  nothing for ⌃⌥T.

## Signing and shipping

Debug matches every other target: ad-hoc, no team, so `scripts/test.sh` and
`scripts/run-mac.sh` stay headless. Release signs manually against a **macOS**
profile, because a provisioning profile is platform-scoped and the iOS one
reports platforms "visionOS, watchOS, and iOS".

| | profile | notes |
|---|---|---|
| iOS (`scripts/ship.sh`) | `TimeConverter App Store` ✓ exists | untouched by this target |
| macOS (`scripts/ship-mac.sh`) | `TimeConverter Mac App Store` — **not created yet** | portal profile type **"Mac"**, not "Mac Catalyst" |

The bundle id is `dev.thisolivier.timeconverter` — **the same as the iOS app**.
A bundle id is scoped per platform in App Store Connect, so this is the macOS
train of app record 6825044484 rather than a second app, which is what makes it
a universal purchase. xcodegen has no objection to two targets sharing one
`PRODUCT_BUNDLE_IDENTIFIER`, and the products never collide on disk because
they build into per-platform directories.

One profile, not two: there is no Control Center on the Mac, so
`TimeConverterControls` stays iOS-only and needs nothing in the portal for this
lane. The exact demand, captured from a dry-run archive, is in
`docs/testflight-setup-checklist.md` under "macOS train".

## QA

```
scripts/run-mac.sh        # build, launch, print the menu-bar log line
scripts/qa-menubar.sh     # the full headless pass + the one manual keypress
scripts/render-glass.sh   # PNGs of the panel in both appearances, no screen
scripts/test.sh --platform mac
```

**The glass itself cannot be verified headlessly, and `render-glass.sh` is
honest about it.** `ImageRenderer` rasterises offscreen, where there is no
window and therefore no desktop to blur — a behind-window `NSVisualEffectView`
draws nothing at all there. The renders substitute the design's own 42% veil so
the ink has something to sit on, which makes them good evidence about layout,
type, hierarchy and both appearances, and no evidence whatsoever about the
frosting, the saturation or the shadow. For those: `scripts/run-mac.sh`, ⌃⌥T,
and drag the panel across some wallpaper.

Item 17's focus fix is as verified as a script can make it — every summon asks
for focus, the request is observable twice in a row, the ladder is ordered,
immediate and finite — but **the `@FocusState` write itself needs a running app
and a real window**, and synthetic keystrokes are off the table here (see the
header of `qa-menubar.sh`). The five-second manual check: launch with
`scripts/run-mac.sh`, switch to another app, press ⌃⌥T, and type without
touching the mouse. The characters should appear in the field. Press ⌃⌥T again
from a third app while the panel is still open and type again — that second
press is the case `controlActiveState` alone does not cover.

`TimeConverterMacTests` is a standalone logic bundle with **no host
application**: `GlobalHotKey.swift` and `SummonPolicy.swift` are members of the
test target as well as the app. A host-application test bundle would launch the
real menu-bar app for every test run, putting a status item in the menu bar and
grabbing ⌃⌥T for the duration — a side effect no test asked for.
