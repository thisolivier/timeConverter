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

## Signing: one extension, two platform trains

Debug matches the app: ad-hoc, no team, so `scripts/test.sh`,
`scripts/run-ios.sh` and `scripts/run-mac.sh` stay headless.

An extension is a separate main executable with its own App ID
(`dev.thisolivier.timeconverter.controls`) and therefore its own distribution
profile per platform — the app's never covers it, and a provisioning profile is
platform-scoped, so the iOS one cannot be reused for the Mac either:

| | profile | entitlements |
|---|---|---|
| iOS (`scripts/ship.sh`) | `TimeConverter Controls App Store` ✓ exists | none |
| macOS (`scripts/ship-mac.sh`) | `TimeConverter Controls Mac App Store` — **not created yet** | `TimeConverterControls-macOS.entitlements` |

The macOS profile is portal type *Mac App Store Connect*, profile type *Mac
Catalyst*; `ship-mac.sh` stops in preflight until it exists, and the portal
steps are under "macOS train" in `docs/testflight-setup-checklist.md`.

`TimeConverterControls-macOS.entitlements` is one line,
`com.apple.security.app-sandbox`, wired in by
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` so only the Release/macOS build gets it.
The extension needs its *own* copy because the host app's sandbox does not reach
across a process boundary, and ingestion enforces this per-executable
(ITMS-90296). No App Group: the control's whole job is to hand a `LaunchRequest`
over by opening the app, so there is no shared storage to share — an App Group
would be another portal capability and another thing to keep in sync for no
behaviour.

(Contrast `TimeConverterMenuBar`, which must carry *no* entitlements and *no*
profile, because it is a loadable plug-in running inside the app's own process.
See that module's readme — the distinction is main-executable versus not.)

`ControlWidget` availability is worth knowing for the Mac lane: it is Mac
Catalyst 18+ but **macOS 26+**, which this project's `MACOSX_DEPLOYMENT_TARGET`
of 26.0 already satisfies.

## Components

- `ConvertATimeControl.swift` — the `ControlWidget`: one
  `ControlWidgetButton(action: ConvertATimeIntent())`.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its one meaningful key is
  `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
