# TimeConverterControls

The iOS widget extension: the Control Center / lock-screen button (backlog
item 11, slice 2) and, since item 36, the **saved-cities home-screen widget**.
Both are loaded out of this one extension by a `WidgetBundle` — a
`ControlWidget` and a `Widget` cannot live in an app target, and a second
extension would mean a second App ID, profile and export entry for nothing.
The target keeps its original name and bundle id for the same reason.

**iOS-only, and staying that way.** There is no Control Center on the Mac, so
the native macOS app (item 16) does not embed this extension. A Mac widget
would be a macOS extension of its own, and is not on the backlog.

## Working patterns

- **The control is a launcher only.** No state, no rendered clock: all of its
  behaviour is `ConvertATimeIntent`, compiled into *both* this target and the
  app (`project.yml`) — the extension needs the type to resolve the button's
  action, the app needs it to run `perform()`. Compiling it into only one is
  the classic "tapping the control does nothing" bug.
- **The widget is the Clocks tab, read-only.** `SavedCitiesWidget` draws the
  local row and up to five favourites through `WorldClock.readings` — the
  same digits, zone lines and offset phrases as the app — one size
  (`.systemLarge`) for the MVP. Tapping it opens the app.
- **It stays on time with a timeline, not a reload.** One entry per minute
  for the next hour, pre-rendered, then `.atEnd`. Entries are free; reloads
  are what WidgetKit budgets.
- **Its data is a mirror of the app's favourites.** The app's
  `FavouritesStore` publishes to `KeychainFavouritesMirror` after every change
  and once at launch (`SavedCitiesWidgetMirror` in `TimeConverter/Clocks/`),
  then asks WidgetKit to reload this kind. The widget reads the same item.
- **`kind` strings are permanent.** `…controls.convert` and
  `…widgets.savedcities` (`SavedCitiesWidgetSupport.kind`, in the package so
  the app's reload call and the widget agree) are what the system stores for
  every placed control or widget. Changing either orphans them.

## Signing: one extension, one platform

Debug matches the app: ad-hoc, no team, so `scripts/test.sh` and
`scripts/run-ios.sh` stay headless.

An extension is a separate main executable with its own App ID
(`dev.thisolivier.timeconverter.controls`) and therefore its own distribution
profile — the app's never covers it.

| | profile | entitlements |
|---|---|---|
| iOS (`scripts/ship.sh`) | `TimeConverter Controls App Store` ✓ exists | `TimeConverterControls.entitlements`: keychain sharing |
| macOS | n/a — not shipped on the Mac | n/a |

**Keychain sharing, not an App Group — for now.** The widget reads the
favourites the app writes, which needs storage both processes can open. The
proper home is an App Group container, but registering one is a portal step
the App Store Connect API does not expose (`docs/testflight-setup-checklist.md`,
"App Group"). Keychain sharing needs no portal step: every profile on the team
already allows `keychain-access-groups = TEAMID.*`, so the app and this
extension simply declare the same group
(`$(AppIdentifierPrefix)dev.thisolivier.timeconverter`, first in both lists)
and the favourites travel as one generic-password item. When the App Group
exists, `KeychainFavouritesMirror` becomes a `UserDefaults(suiteName:)` and
nothing else moves.

## Components

- `TimeConverterWidgetBundle.swift` — `@main`; lists the two widgets.
- `ConvertATimeControl.swift` — the `ControlWidget`: one
  `ControlWidgetButton(action: ConvertATimeIntent())`.
- `SavedCitiesWidget.swift` — the `Widget`, its `TimelineEntry` and the
  `TimelineProvider` (keychain read, hour of minute entries, sample favourites
  for the gallery).
- `SavedCitiesWidgetView.swift` — the face: poster paper and ink, one compact
  row per clock, the empty-state line.
- `TimeConverterControls.entitlements` — the keychain access group.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its one meaningful key is
  `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
