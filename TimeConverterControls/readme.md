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
- **The widget is the Saved tab, read-only, in three sizes** (item 36b,
  from the 2026-11-04 designs). `SavedCitiesWidget` draws the saved places —
  not the local clock; the home screen has one — through
  `WorldClock.readings`, the same digits and offset phrases as the app.
  **The city count chooses the layout, the family chooses what a cell can
  carry**: `WidgetLayoutPlan` (core, shared with Android) decides columns,
  rows, full name or short name (`shortPlaceName`: `LON`, `TOK`, `NYC`,
  `KATH` — 3–4 letters for every place, from `short-names.json`), full /
  short / no caption; one city is a
  hero; five leave the last cell spanning its row; seven or more show six.
  `SavedCitiesWidgetFace` owns the point sizes (`WidgetTypeSizes`): every
  cell in a face shares one numeral size chosen for the widest time at that
  layout's narrowest column, so numerals never resize with the clock. The
  face follows the device's 12/24-hour setting (`Locale.hourCycle`): a 24-hour
  device gets `20:38`, a 12-hour one `8:38` with a small `PM`. Tapping opens
  the app.
- **The face is also compiled into the app** (`project.yml`) for the DEBUG
  `-widgetPreview 1` screen, which draws every family × count × clock
  setting at widget size and writes each to `Documents/widget-previews/` as a
  PNG — the simulator cannot place a widget, so that is how the faces are
  photographed and checked.
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
- `SavedCitiesWidgetFace.swift` — the face, WidgetKit-free: hero, rows and
  grids per `WidgetLayoutPlan`, the type sizes, the hairlines, the empty
  state. Shared with the app's preview screen.
- `SavedCitiesWidgetView.swift` — the WidgetKit wrapper: family from the
  environment, paper container background.
- `TimeConverterControls.entitlements` — the keychain access group.
- `Info.plist` — **generated** by xcodegen from `project.yml` (and gitignored).
  Its one meaningful key is
  `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`.
