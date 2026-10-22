# Launchers

Everything that opens the app *from outside the app* and asks it to start a
fresh conversion (backlog item 11). Two entry points today — an App Shortcut
phrase and the Control Center control in the `TimeConverterControls` extension —
and one shared answer: empty field, keyboard up.

## Working patterns

- **One request, one meaning.** `LaunchRequest` has two cases and one derived
  value, `inputToStartFrom`: `.startFreshConversion` (`""`) for every launcher
  here, and `.summonWithoutReset` (`nil`, i.e. "leave the sentence alone") for
  the Mac menu bar and ⌃⌥T (item 12a, see `TimeConverter/MenuBar/readme.md`).
  Launchers are *access paths*, not a second interaction model: nothing here can
  carry a typed sentence or pre-resolve a zone, so nothing here needs
  parameters. A new launcher reuses a case; a genuinely different request adds
  one and breaks the `switch` in `ContentView` until it is handled.
- **A launcher always clears the field; a summon never does.** Pressing "Convert
  a time" means "start one", so yesterday's half-typed sentence goes. Pressing
  ⌃⌥T means "show me that window again", so it must not. That difference is a
  tested value (`LaunchRequest.inputToStartFrom`), not a line buried in the
  view.
- **The Mac menu bar shares this mailbox.** `MenuBarPresence.summon()` posts
  `.summonWithoutReset` to the same `LaunchRequestInbox.shared`, which is how
  the menu bar inherits the tested focus rule instead of growing a second copy
  of it.
- **The intent talks to the app through a one-slot mailbox.**
  `ConvertATimeIntent` is a foreground intent, so it runs in the app's own
  process — but whether it runs before or after `ContentView` appears depends on
  cold versus warm launch. It posts to `LaunchRequestInbox.shared`; the view
  drains the mailbox from `onAppear` *and* from an observation of
  `pendingRequest`, and `takePendingRequest()` clears as it reads, so whichever
  runs second does nothing. Two presses collapse to one: a single slot, never a
  queue.
- **URLs are a QA and fallback route, not a feature.** `LaunchURLRouter` turns
  `timeconverter://convert` into the same request. It exists because Control
  Center and Siri cannot be scripted but `xcrun simctl openurl` can (see the
  README's QA section). It is deliberately strict — unknown actions route
  nowhere, because honouring a request empties the field.
- **The platform glue is not unit-tested, and that is on purpose.**
  `AppShortcutsProvider`, `ControlWidget` and `@FocusState` can only be proven
  by launching; the decisions around them (which URLs count, what the input
  becomes, focus-on-arrival) are pure values and are covered by
  `LaunchRequestTests`.

## Components

- `LaunchRequest.swift` — the request enum, its `inputToStartFrom` rule, and
  `LaunchRequestInbox`, the mailbox between a launcher and the view. Shared with
  the Mac menu bar.
- `ConvertATimeIntent.swift` — the one `AppIntent` behind every launcher.
  Foreground (`supportedModes = .foreground(.immediate)`, the iOS 26 replacement
  for the deprecated `openAppWhenRun`). **Compiled into both the app and the
  `TimeConverterControls` extension** — see `project.yml`.
- `TimeConverterShortcuts.swift` — the `AppShortcutsProvider`: the Siri /
  Spotlight / Shortcuts-app phrases. Every phrase must contain
  `\(.applicationName)`; spoken synonyms live in `project.yml` under
  `INAlternativeAppNames`.
- `LaunchURLRouter.swift` — `timeconverter://convert` → `LaunchRequest`.
