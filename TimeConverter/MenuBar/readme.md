# MenuBar (app side)

The app's half of the Mac menu-bar presence and the ⌃⌥T global hotkey (backlog
item 12a). The other half is the `TimeConverterMenuBar/` target — a loadable
**macOS-SDK** bundle, because neither `NSStatusItem` nor Carbon's
`RegisterEventHotKey` can be reached from Mac Catalyst at all (importing
`Carbon` under `-target …-macabi` fails at *compile* time).

This module is the app's side of that seam: find the bundle, load it if it is
there, hand it a way back in, and otherwise forget about it.

## Working patterns

- **Optional at every single step.** `builtInPlugInsURL` may be nil, the file
  may be absent (a plain iOS build has no `PlugIns` entry for it at all),
  `Bundle(url:)` may refuse it, `loadAndReturnError()` may fail, the principal
  class may be missing, and the protocol cast may fail even when everything
  else worked. Each outcome produces a sentence in the log and a running app
  with no menu bar. Nothing here may ever be load-bearing for launch — that is
  tested (`MenuBarPlugInTests`), not just intended.
- **One `@objc(…)` name is the whole contract.** `MenuBarHosting` carries an
  explicit Objective-C name because the protocol is compiled twice, against two
  SDKs, and the cast across the bundle boundary resolves by runtime name. With
  a plain `@objc public protocol` the bundle loads, the principal class
  resolves, and the cast fails anyway — the one failure mode with no other
  symptom. `MenuBarPlugInTests` pins the name.
- **Summoning reuses the launchers' mailbox, with the opposite answer about
  typed input.** The menu bar posts `LaunchRequest.summonWithoutReset` to
  `LaunchRequestInbox.shared`, so it inherits the tested focus rule — but
  unlike the Control Center control it leaves the field's contents alone. On the
  Mac the app sits behind other windows all day and ⌃⌥T is pressed to get *back*
  to a sentence mid-edit; clearing it there would be destroying work.
- **Raising the window happens on the bundle's side.** Catalyst has no API for
  an app to bring itself forward; `NSApplication` inside the bundle is the live
  application object of this very process, so activation lives there and only
  the "what should the app do now" half lives here.
- **Mac-only, test-host-never.** `startIfAvailable()` is a no-op outside
  `targetEnvironment(macCatalyst)` and while running as a test host — putting a
  status item up and taking a global hotkey for the length of a unit-test run
  would be a side effect no test asked for.

## Components

- `MenuBarHosting.swift` — the `@objc(MenuBarHosting)` protocol. **Compiled
  into both the app and the `TimeConverterMenuBar` bundle** (see `project.yml`).
  `Foundation` only, no SPM, no `@available`.
- `MenuBarPlugInLoader.swift` — the bundle's name/class/protocol constants and
  the load itself, as a `Result` carrying an optional host and a one-line
  diagnostic. Platform-free, which is what lets both test lanes exercise its
  failure paths.
- `MenuBarPresence.swift` — the app-side owner: loads on launch, logs what came
  up, posts the summon request, and tears down on `willTerminate`.

## QA

`scripts/qa-menubar.sh` covers everything headlessly except the literal
keypress; the README's Mac section has the 10-second manual check. Research and
rationale: `docs/menu-bar-poc-plan.md`.
