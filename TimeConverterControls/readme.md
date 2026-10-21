# TimeConverterControls

The Control Center / lock-screen button, and the project's only second target
(backlog item 11, slice 2). It is a widget extension because the system loads
controls out of an extension — a `ControlWidget` cannot live in an app target.

One file, one button, no state. All of the behaviour is `ConvertATimeIntent`,
which lives in `TimeConverter/Launchers/` and is compiled into *both* targets.

## Working patterns

- **Launcher only.** No timeline, no rendered clock, no typed input — display
  widgets were dropped as decorative (`docs/ux-v1-proposal.md`). The control is
  a faster path to the keyboard and claims nothing more.
- **`kind` is permanent.** `dev.thisolivier.timeconverter.controls.convert` is
  the identity the system stores when a user places the button. Changing it
  orphans every button already placed.
- **`@main` on the `ControlWidget` itself.** `ControlWidget` supplies its own
  `main()`, so a single-control extension needs no `WidgetBundle`.
- **The intent is shared, not duplicated.** `project.yml` lists
  `ConvertATimeIntent.swift` and `LaunchRequest.swift` in this target's sources
  as well as the app's. The extension needs the type to resolve the button's
  action; the app needs it to run `perform()` once foregrounded. Compiling it
  into only one target is the classic "tapping the control does nothing" bug.

## Signing, and the one thing that is not done yet

Debug matches the app: ad-hoc, no team, so `scripts/test.sh`,
`scripts/run-ios.sh` and `scripts/run-mac.sh` stay headless. Release signs
manually against **`TimeConverter Controls App Store`** — a profile that does
not exist yet. An extension needs its own App ID
(`dev.thisolivier.timeconverter.controls`) and its own distribution profile; the
app's cannot cover it. `scripts/ship.sh` fails at the archive step until both
exist — the portal steps are in the root README's shipping note.

## Components

- `ConvertATimeControl.swift` — the `ControlWidget`: one
  `ControlWidgetButton(action: ConvertATimeIntent())`.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its one meaningful key is
  `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
