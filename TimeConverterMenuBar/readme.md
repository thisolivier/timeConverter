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

**Local-only, deliberately.** Apple DTS has twice stated in writing that
embedding a macOS bundle in a Catalyst app is not a supported configuration,
and this project has no Mac delivery lane yet (backlog item 12b). The bundle is
excluded from iOS builds entirely by `platformFilter: macOS` in `project.yml`,
so the shipped `.ipa` has no trace of it — see `docs/menu-bar-poc-plan.md` §3.

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
