---
name: testflight-setup
description: Guide the user step-by-step through first-time TestFlight / App Store Connect setup for a new app on this build server — App ID, app record, distribution profile, Release signing config, ship script, first upload. Use when the user wants to ship a new app to TestFlight, set up App Store Connect, create provisioning profiles, or says "testflight gubbins".
---

# TestFlight Setup (new app, this build server)

Walk the user through taking a locally-building app to its first TestFlight
upload. Shaped by three shipping rounds in the music library project; the
canonical deep docs are:

- `~/sites/musicLibrary/iOSnative/docs/testflight-pipeline.md` — steady-state
  pipeline + common-failure table.
- `~/sites/navidromClient/spike/.signing/context.md` — signing inventory.
  **Secrets live in that dir; never paste file contents into chat.**
- `~/sites/musicLibrary/iOSnative/scripts/ship-naviadmin.sh` — the ship-script
  template for xcodegen projects.

## How to run this skill

This is a **guided interactive process**: some steps happen in the user's
browser (Apple Developer portal / App Store Connect — you cannot do these),
some are yours. For each step: tell the user exactly what to do or do it
yourself, then **verify the step landed before moving on** (verification
commands below). Keep a visible checklist of progress. Ask for the app's
display name, bundle id, and repo path up front if not obvious.

## Phase 0 — verify shared infrastructure (yours)

Already-done one-time machine setup; just confirm it's healthy:

```bash
security unlock-keychain -p "$(cat ~/sites/navidromClient/spike/.signing/keychain.password)" "$HOME/Library/Keychains/spike-build.keychain-db"
security find-identity -v -p codesigning "$HOME/Library/Keychains/spike-build.keychain-db"
# must list: Apple Distribution: Olivier Butler (CNHB9B5GX6)
```

0 identities → re-import the WWDR G3 intermediate (recipe in
testflight-pipeline.md). Team is `CNHB9B5GX6` (individual); it **cannot issue**
CarPlay/Siri entitlements — strip them if the app declares any.

## Phase 1 — Apple portal (user's browser, you verify after)

1. **Register the App ID** at developer.apple.com → Identifiers: explicit
   bundle id `dev.thisolivier.<app>`, capabilities as needed (usually none).
2. **Create the app record** at appstoreconnect.apple.com → My Apps → "+":
   name, primary language, the bundle id, SKU (bundle id works as SKU).
   Ask the user for the **ASC app id** it assigns (numeric, in the URL) and
   record it in the project's shipping doc.
3. **Create an App Store distribution provisioning profile** (Profiles → "+"
   → App Store), selecting the existing Apple Distribution cert. Name it
   `<App> App Store`. Download it.

Verify: user confirms each; profile file exists. If the user browses from a
different machine, give them an scp push command targeting the `.signing/`
dir directly (this server's Tailscale IP works) instead of assuming Downloads.

## Phase 2 — install the profile (yours)

```bash
mv ~/Downloads/<App>_App_Store.mobileprovision ~/sites/navidromClient/spike/.signing/
UUID=$(security cms -D -i ~/sites/navidromClient/spike/.signing/<App>_App_Store.mobileprovision | plutil -extract UUID raw -o - -)
cp ~/sites/navidromClient/spike/.signing/<App>_App_Store.mobileprovision "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
```

Append the new profile (name, UUID, App ID, expiry) to `.signing/context.md`'s
inventory so the next agent finds it.

## Phase 3 — project config (yours)

For an **xcodegen project** (preferred; mirror NaviAdmin's `project.yml`):

- Keep Debug on ad-hoc/automatic signing (local dev stays headless).
- Add a `configs.Release` block on the app target: `CODE_SIGN_STYLE: Manual`,
  `CODE_SIGN_IDENTITY: "Apple Distribution"`,
  `PROVISIONING_PROFILE_SPECIFIER: "<profile name>"`. (Automatic signing
  cannot archive — the team has no Apple Development cert, only Distribution.)
- Signing settings stay **scoped to the app target** — command-line-wide
  provisioning args leak into SPM dependency targets, which reject them.
- `ITSAppUsesNonExemptEncryption: false` in the generated Info.plist
  properties (avoids the "Missing compliance" processing rejection).
- Ensure `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` live in `project.yml`
  and reach Info.plist via `$(VAR)` placeholders.
- `ExportOptions.plist` in the repo: method `app-store-connect` (the
  `app-store` spelling was renamed in Xcode 15.3), manual signing, team
  `CNHB9B5GX6`, the profile mapping. Copy NaviAdmin's as the template.
- **Pre-flight the bundle for App Store validation** — Apple rejects at the
  altool stage, after a long archive+export: the app must have an asset-catalog
  app icon (90023; a single-size 1024px `AppIcon` suffices —
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` — and a placeholder PNG can be
  generated with a short AppKit/swift script) and `UISupportedInterfaceOrientations`
  with all four orientations for iPad multitasking (90474). Bare SwiftUI
  scaffolds have neither.

## Phase 4 — ship script (yours)

Adapt `ship-naviadmin.sh` into the repo's `scripts/ship.sh`:

source `api-key.env` → unlock keychain → bump `CURRENT_PROJECT_VERSION` in
`project.yml` → `xcodegen generate` → archive (`Release`,
`generic/platform=iOS`, `OTHER_CODE_SIGN_FLAGS="--keychain <path>"`,
`-allowProvisioningUpdates=NO` — hard failures beat silent portal
round-trips) → PlistBuddy-assert the archive contains the bumped build number
→ export via ExportOptions.plist → `xcrun altool --upload-app` → print the
Delivery UUID.

Two script traps seen in practice: never capture altool via `VAR=$(...)` under
`set -e` without `|| true` — a nonzero altool exit aborts the assignment itself
and the validation errors vanish without a trace; and when running the ship
script, don't pipe it through `tail`/`grep` without `pipefail` — the pipe
masks the script's exit code.

## Phase 5 — first upload + verify (yours, user confirms in browser)

- Run the ship script. `CFBundleVersion` must be strictly monotonic from now
  on — Apple rejects duplicates at the altool stage (ITMS-90189), after
  archive/export already "succeeded".
- **Delivery UUID ≠ delivered.** Processing is async; check
  `iOSnative/scripts/asc-builds.py <bundle-id>` (or the ASC API) for
  `processingState: VALID`. `PROCESSING` = wait; `INVALID`/`FAILED` =
  investigate, never blind-retry.
- User then: App Store Connect → TestFlight tab → complete export-compliance
  prompt if asked → add themselves as internal tester → install via the
  TestFlight app.

## Mac / Catalyst note

No separate Mac pipeline is needed: iOS TestFlight builds install and run via
TestFlight **on the Mac** too (verified in practice — Amperfy from TestFlight
runs on the user's Mac). Ship iOS; the Mac comes for free. First-time
`xcodebuild` archive may hang on `builtin-RegisterExecutionPolicyException`
(Gatekeeper registration) — let it finish once.
