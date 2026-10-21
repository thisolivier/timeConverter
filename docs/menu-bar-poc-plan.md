# Menu-bar + ⌃⌥T global hotkey — research & POC plan (backlog item 12)

Research session 2026-10-21, Sprint B. Deliverable for backlog item 12 (*L*).
No code landed in the repo; all experiments were throwaway builds under
`/private/tmp/.../scratchpad/menubar-poc/`. Environment: macOS 26.2 (25C56),
Xcode 26.6, macOS SDK 26.5, xcodegen 2.45.4, Apple Silicon.

Claims are tagged `[verified: how]` or `[assumption — needs POC]`.

> **Headline.** The hard part is already proven. This session **built and ran
> the whole bridge end-to-end on this machine**: xcodegen mixed-platform
> project → macOS bundle in `Contents/PlugIns` → loaded by the Catalyst process
> → `NSStatusItem` + `RegisterEventHotKey(⌃⌥T)` → clean teardown. The blocker
> is not the bridge. It is that **this project has no Mac delivery lane at
> all**, and the Catalyst-on-Mac shipping story in `scripts/ship.sh` is
> factually wrong. Verdict: **GO on a local-only POC, NO-GO on shipping it.**

---

## 1. Safe same-machine QA strategy (Olivier's explicit requirement)

**Teardown is guaranteed by Apple, not merely observed.** The macOS 26.5 SDK's
`CarbonEvents.h` says of `UnregisterEventHotKey`: *"You do not need to
unregister a hot key when your application terminates; **the system will take
care of that for you**."* `[verified: CarbonEvents.h:15494]`. The same header
documents `eventHotKeyExistsErr` as firing only for a hotkey *"already
registered in the current process (Note that it is **not** an error to register
the same hotkey in multiple processes)"* `[verified: CarbonEventsCore.h:142]`.
Registration is WindowServer state keyed to the process's CGS connection, so it
dies with the process by any means.

That matches what I measured: same combo twice *inside one process* → −9878;
two *separate processes* → both `noErr`, both live `[verified: dup.swift +
two-process test]`. After `SIGKILL` with **no** `UnregisterEventHotKey`, a fresh
process registers the same combo with `noErr` and no strays remain
`[verified: hotkey.swift --no-unregister]`. Clean teardown
(`UnregisterEventHotKey` → `noErr`, `removeStatusItem`) exits 0
`[verified: POC run]`. Even the strict case is leak-free: an **exclusive**
registration does return −9878 to a second process, yet is still reclaimed after
the owner is SIGKILLed `[verified: independent probe]`. Call
`UnregisterEventHotKey` on orderly quit anyway — but a crash strands nothing.

**⌃⌥T is free on this machine; ⌃⌥Space is not.** Verified via
`CopySymbolicHotKeys()` rather than the preferences plist — the plist holds only
*modified* entries (19 here), while the API reports the real picture: **229
symbolic hotkeys, 171 enabled**, of which **zero are on keycode 17 (T)**
`[verified: shk.swift]`. The positive control proves the method: keycode 49
(Space) carries six registrations including **`mods=0x1800`
(`controlKey|optionKey`) enabled** — i.e. ⌃⌥Space, alongside ⌘Space, ⌃Space,
⌃⌘Space, ⌥⌘Space. **Olivier's ⌃⌥T decision is vindicated by data: the
proposal's original ⌃⌥Space suggestion would have collided** with input-source
switching. No app-level overrides exist either (`pbs NSServicesStatus` empty, no
`NSUserKeyEquivalents` in any domain), and **no third-party hotkey grabber is
installed** — no Alfred, Raycast, Rectangle, Hammerspoon, BetterTouchTool,
Karabiner, Keyboard Maestro `[verified: /Applications listing + per-app probe]`.

Residual blind spot: another app holding ⌃⌥T **non-exclusively** is
undetectable — you get `noErr` and silently share, with no public API to
enumerate other processes `[verified: SDK header + absence of API]`. Registering
with `kEventHotKeyExclusive` works as a one-off *probe* (−9878 ⇒ someone holds
it exclusively), but taking exclusivity suppresses other apps' hotkeys, so use
it to ask the question, not to ship.

**Two traps that shape the QA script.** First, `RegisterEventHotKey` returns
`noErr` even for a combo the system already owns — registering ⌃⌥Space returned
`noErr` `[verified: probe.swift KEYCODE=49]`, because symbolic hotkeys are
consumed at a higher layer. Second, a **second instance via `open -n`
double-registers**: both processes get `noErr`, both live, and which one
receives a press is undefined `[verified: two-process test]`. So `noErr` is not
proof the hotkey fires, and QA must assert single-instance before pressing.

**Cost is ~0.6% of a simulator.** The POC with bundle loaded, status item live
and hotkey registered measured **78.4 MB RSS, 0.1% CPU**. The Debug Catalyst
`TimeConvertor` that has run here for 22 hours is 30.6 MB; the currently-running
iOS simulator totals **~12.3 GB** `[verified: ps sampling]`. "Bounded to roughly
what a simulator costs" is met with two orders of magnitude of headroom. No
restart, no logout, no `sudo`, no TCC grant, no login item, no `launchctl`
registration anywhere in this.

**QA runs exactly like `run-mac.sh` today** — build to `build/DerivedData`,
`open` the `.app`; already established practice here (that 22-hour-old process).

**Blast radius of a failed bundle load: zero — already proven, not just
designed-for.** In the POC the load path is `guard`-chained with no force
unwraps; when the protocol cast genuinely failed, the app printed `NO BUNDLE
LOADED — app continues without menu-bar features` and ran on normally, exiting 0
`[verified: POC first run]`. Keep every step optional (`Bundle(url:)`,
`loadAndReturnError()`, `principalClass`, the cast, `start()`): log, continue.
The iOS/iPad app is untouchable by construction — see §3.

### Concrete QA checklist (`scripts/qa-menubar.sh`, Debug only, never in `test.sh`)

1. **Pre-flight:** `pgrep -f 'Debug-maccatalyst/TimeConverter' && exit 1`.
2. **Collision snapshot:** call `CopySymbolicHotKeys()`; assert no *enabled*
   entry has `code == kVK_ANSI_T` and `mods & 0x1F00 == 0x1800`. Use the API,
   **not** `defaults read com.apple.symbolichotkeys` (which would miss most of
   the 229). Cache it — the header warns the call is O(number of hotkeys).
3. **Build + launch** via the existing `run-mac.sh` path.
4. **Assert placement:** `Contents/PlugIns/MenuBarKit.bundle` exists and
   `vtool -show-build` on its binary reports `platform MACOS`.
5. **Assert load succeeded** from the app's log diagnostics.
6. **Single-instance:** `pgrep -cf 'TimeConverter.app/Contents/MacOS'` == 1.
7. **Manual press test** — press ⌃⌥T from an unlocked GUI session; assert the
   window activates with the field focused (item 10).
8. **Teardown:** quit, assert `pgrep` empty, relaunch, assert `noErr` again.
9. **Crash path:** `kill -9`, relaunch, assert `noErr` again.
10. **Negative path:** `mv` the bundle out of `PlugIns`, launch, assert the app
    still runs and the window still works, `mv` back.

**Step 7 cannot be automated from this shell.** Synthetic keystroke injection is
TCC-blocked: `osascript ... keystroke "t" using {control down, option down}`
hangs until killed (exit 142 under a 10 s alarm), because the SSH shell has no
Accessibility grant and the consent prompt cannot be answered while the screen
is locked `[verified: osascript timeout test; CGSessionCopyCurrentDictionary
reports CGSSessionScreenIsLocked = 1]`. Steps 1–6 and 8–10 are fully headless.
Granting Accessibility to an automation harness purely to test a hotkey would be
a far bigger blast radius than the feature — don't. Budget one short interactive
pass (Screen Sharing / unlocked session) per POC iteration.

---

## 2. XcodeGen expression of the bundle target — verified by building it

A mixed-platform `project.yml` works; I generated and built one
`[verified: scratchpad/menubar-poc/xcgtest]`:

```yaml
targets:
  TimeConverter:
    type: application
    platform: iOS            # + SUPPORTS_MACCATALYST: YES, as today
    sources: [TimeConverter, Shared]
    dependencies:
      - target: MenuBarKit
        platformFilter: macOS   # emits `platformFilter = maccatalyst`
        embed: true             # REQUIRED — `copy` is ignored unless embed is true
        link: false             # must NOT be in Link Binary With Libraries
        codeSign: true
        copy:
          destination: plugins  # -> dstSubfolderSpec = 13; NO subpath
  MenuBarKit:
    type: bundle
    platform: macOS
    sources: [MenuBarKit, Shared]
    info:
      path: MenuBarKit/Info.plist
      properties:
        CFBundlePackageType: BNDL
        NSPrincipalClass: MenuBarController
    settings:
      base:
        WRAPPER_EXTENSION: bundle
        SKIP_INSTALL: "YES"
```

Verified outcomes:

- `type: bundle` → `com.apple.product-type.bundle`; `platform: macOS` →
  `SDKROOT = macosx` while the app keeps `SDKROOT = iphoneos`. **XcodeGen does
  no cross-target platform validation and accepts this** (unlike Tuist, which
  hard-rejects it) `[verified: generated pbxproj + xcodegen source]`.
- `copy: {destination: plugins}` → `PBXCopyFilesBuildPhase` with
  `dstSubfolderSpec = 13`, `dstPath = ""` `[verified: pbxproj]`. **The key is
  `copy:` (an object), not `copyFiles:` or `copyPhase:`** — and there is no
  XcodeGen setting preset for `type: bundle`, so a wrong/absent `copy:`
  silently lands the bundle in `Contents/Resources`, where `builtInPlugInsURL`
  will never find it `[verified: XcodeGen source — a `bundle` falls through to
  `copyResourcesReferences`; the unanswered cause of XcodeGen issue #1157]`.
  Omit `subpath`: `PLUGINS_FOLDER_PATH` already resolves to `Contents/PlugIns`
  for Catalyst, so adding one yields `Contents/PlugIns/Contents/PlugIns`.
- Catalyst build → `App.app/Contents/PlugIns/MenuBarKit.bundle`, bundle binary
  `platform MACOS`, host `platform MACCATALYST`, signed with `CodeSignOnCopy`
  `[verified: find + vtool + codesign -dv]`.

**Runtime load — works, with one sharp trap.** `Bundle.main.builtInPlugInsURL`
**resolves correctly** for a Catalyst app (no manual path construction),
`loadAndReturnError()` succeeds, `principalClass` resolves `[verified: POC]`.
But the shared protocol needs an **explicit ObjC name**:

```swift
// Shared/MenuBarHosting.swift — one file, member of BOTH targets, Foundation only
@objc(MenuBarHosting)                       // ← load-bearing
public protocol MenuBarHosting: NSObjectProtocol {
    init()
    func start(onActivate: @escaping () -> Void) -> Bool
    func stop()
}
```

I hit this for real: with a plain `@objc public protocol`, the bundle loaded and
`principalClass` resolved but **the cast to the protocol failed** — the two
compilations (iOS SDK, macOS SDK) mangle the protocol name per-module and
disagree on its runtime identity. Adding `@objc(MenuBarHosting)` plus
`@objc public required override init()` on the implementation fixed it and the
POC ran clean `[verified: failure and fix observed in consecutive runs]`. A
pure-Swift `@objc` protocol with dual target membership suffices — **no
Objective-C bridging header needed**. Keep the file importing `Foundation` only.
Use `loadAndReturnError()` over `load()`/`classNamed` so failures are
diagnosable. Also note `@available`/`#available` **misbehave inside the bundle**
(it is a macOS-platform binary, so iOS predicates are meaningless)
`[verified: Apple forums 769279]`.

Known landmine: archiving a Catalyst app that embeds a macOS target fails with
`Multiple commands produce '…/X.o'` **if both targets depend on the same local
Swift package** `[verified: Apple forums 814686]`. Not an issue today — keep the
shared protocol file SPM-free.

---

## 3. Signing / TestFlight risk — the real blocker, bigger than item 12

### The iOS lane is safe, because the bundle is never in it

`platformFilter: macOS` → `platformFilter = maccatalyst` on both the target
dependency and the embed build file, so a `generic/platform=iOS` build skips
both. I built it: the iOS `App.app` is a flat bundle with **no `PlugIns` and no
trace of the bundle**, and the build succeeds `[verified: xcodebuild
-destination 'generic/platform=iOS' + find]`.

**This retires the backlog's biggest budgeted risk for free.** Adding the bundle
cannot break `scripts/ship.sh`, because the `.ipa` is structurally identical to
today's. The throwaway archive upload the backlog budgets **is not needed** —
the answer is "nothing happens; the bundle isn't there." Don't spend a build
number measuring nothing.

### …which is also exactly the problem

`scripts/ship.sh:9` claims: *"One iOS archive covers everything: iOS TestFlight
builds install and run via TestFlight on the Mac too, so there is no separate
Mac/Catalyst ship lane."* **This is false.** Against this project's own
artifacts and ASC record:

- The existing archive is an **iOS** archive — `vtool -show-build` on
  `build/TimeConverter.xcarchive/.../TimeConverter` reports `platform IOS`, and
  the app is a **flat iOS bundle** (`embedded.mobileprovision` at root, no
  `Contents/`) `[verified: vtool + find]`.
- ASC app 6825044484 has both `IOS` and `MAC_OS` platform version records but
  **only an `IOS` TestFlight train**; builds 3 and 4 both have
  `lsMinimumSystemVersion = null`, i.e. iOS builds
  `[verified: App Store Connect API]`.
- The `TimeConverter App Store` profile's `Platform` is
  `[iOS, xrOS, visionOS]` — **not macOS**; it cannot sign a Catalyst
  distribution build `[verified: security cms -D]`.
- `project.yml` sets `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: "NO"`, removing the
  "iPhone and iPad app on Mac" path. With no Mac build either, **there is
  currently no way to get this app onto a Mac via TestFlight at all**
  `[verified: project.yml + ASC state]`.
- Only `Apple Distribution` and `Apple Development` identities exist here, with
  **no Mac installer certificate** (`security find-identity -p macappstore`
  reports both "Missing required extension") and **zero `.provisionprofile`
  files** anywhere `[verified: security find-identity + find]`.
- Apple is explicit these are separate artifacts: a Catalyst build needs its own
  `-destination 'platform=macOS,variant=Mac Catalyst'` archive, exported as a
  `.pkg`, uploaded as the **macOS** platform `[verified: ASC Help "Add
  platforms"; Apple forums 772992 (DTS)]`.

**Crucially: an iOS `.ipa` on an Apple silicon Mac runs as "iPhone and iPad app
on Mac" in the iOS runtime — not as Catalyst.** A macOS-SDK AppKit bundle would
never load there even if embedded `[verified: Apple forums 772992]`. The feature
cannot reach a Mac through today's pipeline under any configuration.

### If the Mac lane is ever built

Two real precedents, both specific to a macOS bundle embedded in a Catalyst app:
`ITMS-90283 "Invalid Provisioning Profile … [Invalid
'com.apple.application-identifier' entitlement value]"` on the embedded bundle,
and total upload failure when the App ID prefix ≠ Team ID with a secondary
AppKit bundle present. **Both Apple forum threads are unanswered**
`[verified: 672793, 672800, 700168]`. Good news: this project's **App ID prefix
equals its Team ID** (`CNHB9B5GX6` both), sidestepping the variable both threads
implicate `[verified: PlistBuddy on the decoded profile]`. Correct config is:
bundle **signed** with the same identity, **no embedded profile, no
entitlements** — per TN3125, traditional plug-ins need no profile and should not
carry entitlements. Same-Team-ID signing satisfies library validation, so
`com.apple.security.cs.disable-library-validation` is **not** needed
`[verified: TN3125]`. Whether *this* setup trips ITMS-90283 is
`[assumption — unknowable without a real Catalyst archive]`.

**Apple's position on the architecture:** not merely undocumented but
**explicitly unsupported, twice in writing**. DTS: *"Placing a macOS bundle
target inside of a Mac Catalyst app in order to use AppKit is not a supported
configuration"* and *"there's no supported scenario for your target setup."*
Apple via PSPDFKit: *"We do not recommend doing this and cannot guarantee
support in the future."* Known consequences beyond `@available`: `MKMapView`
loaded from such a bundle crashes with an unrecognized selector
`[verified: Apple forums 769279, 751162; mjtsai.com]`. Note also that
overdesigned.net's status-menu article — cited in the UX proposal — is actually
a *different* pattern (an embedded helper **app** in
`Contents/Library/LoginItems` via `SMLoginItemSetEnabled`), so it is not
precedent for this `[verified: reading the article]`. I found **no confirmed
approval and no confirmed rejection** of a Catalyst app with a loadable AppKit
bundle.

**Blast radius of a throwaway upload** — a failed/invalid build costs a consumed
build number and an undeletable row in the build list (builds can only be
**expired**; they auto-expire after 90 days) `[verified: ASC Help]`. Two
caveats: **macOS requires `CFBundleVersion` to increase monotonically across all
version trains** (iOS does not), so burned numbers are unrecoverable on the Mac
side `[verified: forums 714645]`; and one **unresolved** report says an Invalid
Binary can wedge new-version submission `[verified as a report, unconfirmed as
systemic: 785872]`.

---

## 4. Carbon hotkey specifics — verified empirically on this machine

Constants read out of the SDK by a compiled probe rather than quoted from
memory `[verified: hotkey.swift output]`: `kVK_ANSI_T = 17`,
`controlKey = 4096 (0x1000)`, `optionKey = 2048 (0x0800)`, combined **6144
(0x1800)**, `eventHotKeyExistsErr = −9878`, `eventHotKeyInvalidErr = −9879`.

These are **Carbon bitmasks, not `NSEvent.ModifierFlags`** (whose `.control` is
`0x040000`, `.option` `0x080000` — the values in `com.apple.symbolichotkeys`,
where ⌃⌥ reads as `786432`). Mixing the families is the classic bug here
`[verified: both observed side by side]`. `kVK_ANSI_T` identifies a **physical
key position**: `Events.h` states the `kVK_ANSI_*` constants *"identify physical
keys… labeled according to the key position on an ANSI-standard US keyboard"*
and other layouts *"may have the key label on a different physical key"*
`[verified: Events.h:185]`. A Dvorak user pressing the key *labelled* T would
not fire ⌃⌥T. Fine to hardcode — but if the UI ever names the shortcut, it
names the physical key.

**The bundle is not optional — Carbon cannot be imported from Catalyst at
all.** `Carbon.framework` is absent from the SDK's `System/iOSSupport` tree, and
`#import <Carbon/Carbon.h>` under `-target arm64-apple-ios*-macabi` fails at
**compile** time (`unknown type name 'HIShapeRef'`), not link time
`[verified: independent build test]`. The macOS-SDK bundle is what makes the
call legal. (A `dlopen`/`dlsym` route with hand-declared prototypes also returns
`noErr` from a macabi binary `[verified: independent runtime test]`, but buys
nothing here: `NSStatusItem` needs the macOS SDK regardless, and it trades a
signed bundle for unchecked hand-written prototypes.)

**No Catalyst-specific gotcha found.** `RegisterEventHotKey` with
`GetApplicationEventTarget()` returned `noErr` from inside a Catalyst process
with the registration living in a loaded macOS bundle, and `InstallEventHandler`
for `EventTypeSpec(kEventClassKeyboard, kEventHotKeyPressed)` installed with
status 0 `[verified: POC run]`. Both shipping Swift libraries
(`KeyboardShortcuts`, `HotKey`) use **`GetEventDispatcherTarget()`** for both
calls; it is the root of the propagation chain, so prefer it — the only hard
rule is that the handler be installed on the same target you register against
`[verified: library source; both targets tested working]`. Register on the
**main thread**: the header marks these *"Not thread safe"* (no internal
locking; a background call still returns `noErr`), the handler runs main-thread
regardless, and `NSStatusItem` requires it `[verified: SDK header + POC]`.

**The no-accessibility-permission claim holds, confirmed two ways.** Everything
ran with **zero TCC prompts and zero granted permissions**, in the same session
where `osascript` keystroke *injection* was blocked outright — that contrast is
itself the proof. An independent probe printed, in the same process as a
successful registration: `AXIsProcessTrusted = 0`,
`CGPreflightListenEventAccess = 0`, `CGPreflightPostEventAccess = 0`,
`register -> 0` `[verified: POC + preflight probe]`. Mechanically expected:
registration goes through the WindowServer, which delivers only the one
pre-declared chord, so the app never sees the keystream and there is nothing for
TCC to protect. `CGEventTap` and `NSEvent.addGlobalMonitorForEvents` **do**
require Input Monitoring, and fail nastily — reporting success then silently
never firing `[verified: Apple forums 735223 (DTS)]`.

**API health:** `RegisterEventHotKey`, `UnregisterEventHotKey`,
`InstallEventHandler` and `CopySymbolicHotKeys` carry **no deprecation
attribute** in SDK 26.5, and the POC compiled with zero deprecation warnings
`[verified: header annotations + build]`. Usable from **sandboxed App Store apps
with no entitlement** `[verified: SDK + Apple forums 763878, scoped to
sandboxed apps]`. Two caveats: DTS has said it *"can't honestly recommend"* the
API, being tied to the legacy Carbon toolbox and possibly removed eventually
`[verified: 735223]`; and macOS 15.0–15.1 briefly rejected hotkeys whose only
modifiers were Option/Shift, relaxed in 15.2 `[verified: 763878 + FB15168205]` —
**⌃⌥T includes Control, so it was never affected.**

**Why the press test is the one thing left.** `RegisterEventHotKey` installs
**no `CFRunLoopSource`** — the main run loop's source list is identical before
and after registration `[verified: independent probe]`. Delivery depends on
something *pulling* the process's WindowServer event queue, i.e.
`NSApplication`'s event loop; a process running a bare `CFRunLoopRun()`
registers with `noErr` and **never fires**. A Catalyst process does have a live
`NSApplication`, so it should pump these normally — but no public report exists
of Carbon global hotkeys from Catalyst either way
`[assumption — needs POC]`. I could not test it: the GUI session is locked and
injection is TCC-blocked (§1), and `noErr` is not evidence (it also returns
`noErr` for combos the system owns). **This is the single remaining unknown in
the whole bridge.**

---

## 5. Go / no-go

**GO on the local POC — in fact it is already done — and NO-GO on shipping it.**
Split item 12 in two.

**Why GO locally.** Backlog risks (a) and (b) are **retired**. The smallest
compilable proof the brief asked for — bundle loads in Catalyst, status item
appears, hotkey registers, clean teardown — was built and run this session, all
of it except the literal keypress. It came to ~90 lines, not 150–250. The QA
story is genuinely safe: 78 MB, 0.1% CPU, per-process registration with Apple's
documented no-leak guarantee, no permissions, no restarts, and a verified
graceful-degradation path when the bundle is absent.

**Why NO-GO on shipping.** Risk (c) is not "the biggest risk" — it is a
different, larger piece of work that item 12 does not contain. There is no
Catalyst archive, no Mac distribution certificate, no macOS provisioning
profile, no macOS TestFlight train, and the documented shipping story is wrong.
On top of that Apple DTS has twice stated the architecture is unsupported.
Shipping this means building a whole second delivery lane for a feature Apple
says it may break.

### Recommended scope

**Item 12a — local-only menu-bar POC (S, ~half a day).** Land the bridge behind
`#if targetEnvironment(macCatalyst)` and a `DEBUG`/defaults-flag gate so it
cannot affect a shipped build. Deliverables: `MenuBarKit` target in
`project.yml`, `Shared/MenuBarHosting.swift` with `@objc(MenuBarHosting)`,
`MenuBarController` owning the status item and hotkey, optional-load wiring,
`scripts/qa-menubar.sh` implementing §1, and one interactive press test. Gives
Olivier the feature on his own machine today.

**Item 12b — Mac distribution lane (L, separate, and not obviously worth it).**
Mac App Distribution + Mac installer certificates, a macOS App Store profile, a
Catalyst archive lane in `ship.sh` (`-destination 'platform=macOS,variant=Mac
Catalyst'` → `.pkg` → upload as the macOS platform), and the macOS TestFlight
train. **Do this independently of item 12**, because it is what makes the Mac
app shippable *at all*, hotkey or not. Only then is ITMS-90283 even askable.

**Immediately, independently of both: fix the premise.** Correct the "one iOS
archive covers everything" comment at `scripts/ship.sh:9` (and any echo of it in
`README.md`), and note in the backlog that Mac TestFlight delivery does not
currently exist. That claim is load-bearing for item 11 and anything else
Mac-facing, and it is wrong today. Highest-value finding of this session; costs
minutes.

### Ordered risk-retirement sequence (revised)

1. ~~xcodegen bundle target + embed + load across a shared protocol~~ — **done
   this session**, with the `copy:`-key and `@objc(Name)` traps found and solved.
2. ~~Carbon `RegisterEventHotKey` from a Catalyst-hosted macOS bundle~~ —
   **done**: `noErr`, constants confirmed, no permission needed, clean teardown,
   no crash leak (now backed by Apple's own header guarantee).
3. **One interactive press test** on an unlocked session — the only remaining
   technical unknown (~10 minutes).
4. **Fix the distribution premise in the docs** — minutes, highest value.
5. *Then, only if Olivier wants the Mac app shippable:* build the Catalyst
   delivery lane (12b). The embedded-bundle signing question is the **last**
   step, not the first — it cannot be tested until a Mac archive exists.

---

*Throwaway experiments backing this document (outside the repo):*
`scratchpad/menubar-poc/hotkey.swift` (constants, register/unregister, SIGKILL
leak test), `probe.swift` (system-claimed-combo control), `dup.swift`
(duplicate-registration semantics), `shk.swift` (`CopySymbolicHotKeys`
enumeration), `session.swift` (window-server session), `xcgtest/` (full
xcodegen + Catalyst + macOS-bundle + status item + hotkey POC). Nothing was
written to the repo except this file; no commits were made.
