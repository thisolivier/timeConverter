# TimeConverterMenuBar

A loadable **macOS-SDK bundle** that gives the Mac Catalyst app a menu-bar
status item and the ⌃⌥T global hotkey (backlog item 12a). Not an app extension:
a traditional plug-in, copied into `TimeConverter.app/Contents/PlugIns` and
loaded by the app at launch through `NSPrincipalClass`.

**Why a separate target at all.** Mac Catalyst cannot reach either API. `Carbon`
is absent from the SDK's `iOSSupport` tree and importing it under
`-target …-macabi` fails at *compile* time; `NSStatusItem` needs AppKit. A
macOS-platform binary loaded into the Catalyst process is what makes both calls
legal.

**Excluded from iOS builds entirely** by `platformFilter: macOS` in
`project.yml`, so the shipped `.ipa` has no trace of it. The Mac Catalyst
archive (`scripts/ship-mac.sh`, backlog item 12b) *does* include it, which makes
this bundle's code signature the riskiest thing in that lane — see
`docs/menu-bar-poc-plan.md` §3 and the "macOS train" section of
`docs/testflight-setup-checklist.md`. Apple DTS has called embedding a macOS
bundle in a Catalyst app unsupported three times across 2024–2025, so whether
it survives ingestion and review is genuinely unknown.

## How this bundle must be signed, and why there is only one way

| | this `.bundle` | the app and the `.appex` |
|---|---|---|
| entitlements | **none** | `com.apple.security.app-sandbox` |
| provisioning profile | **none** | one each, `Contents/embedded.provisionprofile` |
| sandbox | inherits the host process's | its own |

This is not a tuning choice. Apple: *"Plug-ins don't declare their own
entitlements. Instead, they inherit the entitlements of the host process"*
("Notarizing macOS software before distribution"), and *"Entitlements only make
sense on a main executable… Do not apply entitlements to library code. It
doesn't do anything useful and can prevent your code from running"* ("Creating
Distribution-Signed Code for Mac"). The test for *main executable* is
`file`: this bundle's binary is a `dynamically linked shared library`, not an
`executable`.

The practical stakes are `ITMS-90283 "Invalid Provisioning Profile… [Invalid
'com.apple.application-identifier' entitlement value]"`. Every public report of
it naming an embedded `.bundle` is about a provisioning profile found *inside*
that bundle — so the configuration with no profile and no entitlements removes
the entire validation surface. One contributing factor those reports share, an
App ID prefix that is not the Team ID, does not apply here: this project's are
both `CNHB9B5GX6`.

`scripts/ship-mac.sh` asserts all of it on the archive before it will upload —
no entitlements on this bundle, no `embedded.provisionprofile` under any
`.bundle/`, and the sandbox entitlement present on the app and the extension.

What *does* matter for signing is the identity: the Release config signs with
the team's own Apple Distribution certificate. Release builds get the hardened
runtime, whose library validation requires the plug-in and its host to share a
Team ID — which is why an ad-hoc *Release* build cannot load this bundle at all
(`AMFI … is adhoc signed`, and the loader reports
`menu bar unavailable: load failed`), while an ad-hoc Debug build loads it
fine. Something to know before reading an ad-hoc load failure as a code bug.
The App Sandbox itself is not a problem: `scripts/run-mac.sh --sandboxed`
builds a sandboxed Debug app and the bundle loads and registers ⌃⌥T normally.

## Working patterns

- **Nothing here may be required for the app to work.** The app loads this
  optionally and logs failures; correspondingly, nothing in here fails loudly.
  `start()` returns a sentence for the log rather than a `Bool`, because "status
  item up, hotkey unavailable" is a normal outcome worth naming.
- **That sentence is the only evidence QA has, so it must describe what
  happened, not what was asked for.** `start()` says `status item` only when
  `NSStatusBar` gave a button *and* AppKit placed it in a status-bar window;
  otherwise it says so, and `scripts/qa-menubar.sh` fails. A hardcoded
  "status item" would turn that check into a tautology.
- **An unavailable hotkey is not an error.** `eventHotKeyExistsErr` means this
  process already asked or another process holds ⌃⌥T exclusively — notably what
  a second copy launched with `open -n` can see. The status item still works by
  click, so it is reported and shrugged off.
- **Everything is main-actor.** `NSStatusItem` requires it and the Carbon
  headers are marked "not thread safe" (a background call still returns
  `noErr`, which is the trap). The one `MainActor.assumeIsolated` is in the C
  hotkey callback, which the application's own event loop delivers on the main
  thread.
- **Carbon bitmasks, not `NSEvent.ModifierFlags`.** `controlKey|optionKey` is
  `0x1800`; the AppKit spelling of ⌃⌥ is `0x0C0000`. Mixing the two families
  silently registers a different chord, and is the classic bug in this corner of
  the OS. `kVK_ANSI_T` is likewise a *physical key position*, not the letter
  printed on the key.
- **No permissions, and that is the point of Carbon here.** The WindowServer
  delivers only the one pre-declared chord, so the process never sees the
  keystream and there is nothing for TCC to protect. `CGEventTap` and
  `NSEvent.addGlobalMonitorForEvents` both need Input Monitoring and fail by
  reporting success and then never firing.
- **Teardown is tidiness, not correctness.** Registration is per-process
  WindowServer state and the system reclaims it however the process dies —
  Apple's own header says so, and `scripts/qa-menubar.sh` proves it after a
  `kill -9`.
- **No `@available` / `#available`.** This is a macOS-platform binary, so iOS
  version predicates do not mean what they look like here.

## Components

- `MenuBarController.swift` — the `NSPrincipalClass`. Owns the status item (a
  template-rendered clock glyph), activates the app and raises its window on a
  click or a press, then hands control back to the app through `onSummon`.
- `GlobalHotKey.swift` — the Carbon registration: ⌃⌥T on
  `GetEventDispatcherTarget()`, the event handler installed on that same
  target, and the C callback that routes a press back to the instance.
- `TimeConverter/MenuBar/MenuBarHosting.swift` — the shared `@objc` protocol,
  compiled into this target too. See that module's readme.
- `Info.plist` — **generated from `project.yml`**; do not edit directly.
