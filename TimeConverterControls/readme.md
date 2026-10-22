# TimeConverterControls

The Control Center / lock-screen button (backlog item 11, slice 2). It is a
widget extension because the system loads controls out of an extension — a
`ControlWidget` cannot live in an app target.

One file, one button, no state. All of the behaviour is `ConvertATimeIntent`,
which lives in `TimeConverter/Launchers/` and is compiled into *both* targets.

**iOS-only, and staying that way.** There is no Control Center on the Mac, so
the native macOS app (item 16) does not embed this extension — which means it
needs no macOS App ID capability, no macOS provisioning profile and no macOS
entitlements file. The Catalyst lane used to require all three; retiring
Catalyst deleted that work rather than moving it.

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
  `ConvertATimeIntent.swift` in this target's sources as well as the app's. The
  extension needs the type to resolve the button's action; the app needs it to
  run `perform()` once foregrounded. Compiling it into only one target is the
  classic "tapping the control does nothing" bug.
- **It links `TimeConverterCore` too.** `LaunchRequestInbox` moved into the
  package with the rest of the launch logic and the intent posts to it, so the
  extension takes the package dependency as well. Harmless duplication: it is a
  static library, and the extension never touches the bundled gazetteer.

## Signing: one extension, one platform

Debug matches the app: ad-hoc, no team, so `scripts/test.sh` and
`scripts/run-ios.sh` stay headless.

An extension is a separate main executable with its own App ID
(`dev.thisolivier.timeconverter.controls`) and therefore its own distribution
profile — the app's never covers it.

| | profile | entitlements |
|---|---|---|
| iOS (`scripts/ship.sh`) | `TimeConverter Controls App Store` ✓ exists | none |
| macOS | n/a — not shipped on the Mac | n/a |

No App Group either: the control's whole job is to hand a `LaunchRequest` over
by opening the app, so there is no shared storage to share — an App Group would
be another portal capability and another thing to keep in sync for no
behaviour.

## Components

- `ConvertATimeControl.swift` — the `ControlWidget`: one
  `ControlWidgetButton(action: ConvertATimeIntent())`.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its one meaningful key is
  `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
