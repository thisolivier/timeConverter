# TestFlight / App Store Connect setup checklist — TimeConverter

Synthesized 2026-10-20 from the music library project's three shipping rounds.
Source docs (read these for depth; this file is just the checklist):

- `~/sites/musicLibrary/iOSnative/docs/testflight-pipeline.md` — steady-state
  archive/export/upload pipeline + common-failure table (the keeper doc).
- `~/sites/navidromClient/spike/.signing/context.md` — canonical team id,
  cert/keychain/API-key inventory. Secrets live in that dir; never paste them.
- `~/sites/musicLibrary/iOSnative/NaviAdmin/README.md` §Shipping +
  `iOSnative/scripts/ship-naviadmin.sh` — the newest pipeline and the right
  template for us (xcodegen project, bump in `project.yml`, regenerate, ship).

## Already done (shared infrastructure — do NOT redo)

- Apple individual team `CNHB9B5GX6`; **Apple Distribution** cert (one cert
  covers TestFlight + ad-hoc) in the dedicated build keychain
  `~/Library/Keychains/spike-build.keychain-db` (auto-locks after 6h).
- App Store Connect API key `2A3HT77RSP` (App Manager role) — env in
  `~/sites/navidromClient/spike/.signing/api-key.env`.
- WWDR G3 intermediate imported (if `security find-identity` ever shows 0
  identities, re-import — recipe in testflight-pipeline.md).

## One-time, per new app (the actual TimeConverter to-do)

1. [x] **Register the App ID** — done 2026-10-20: `dev.thisolivier.timeconverter`.
2. [x] **Create the app record** — done 2026-10-20: store name
       **"Time Converter 3000"**, ASC app id **6825044484**
       (bundle id `dev.thisolivier.timeconverter`).
3. [ ] **Create an App Store distribution provisioning profile** for the bundle
       id against the existing Apple Distribution cert. Download it to
       `~/sites/navidromClient/spike/.signing/` (naming pattern:
       `Spike_TimeConverter_App_Store.mobileprovision`) AND install it at
       `~/Library/MobileDevice/Provisioning Profiles/<UUID>.mobileprovision`
       where xcodebuild looks.
4. [x] **ExportOptions.plist** in this repo — copy NaviAdmin's (manual signing,
       team `CNHB9B5GX6`, the new profile name).
5. [x] **project.yml Release config**: keep Debug on the current ad-hoc
       settings; add a `configs.Release` block with `CODE_SIGN_STYLE: Manual`,
       `CODE_SIGN_IDENTITY: "Apple Distribution"`,
       `PROVISIONING_PROFILE_SPECIFIER: <profile name>` — exactly NaviAdmin's
       pattern (automatic signing can't archive: the team has no Apple
       Development cert, only Distribution). Keep signing settings scoped to
       the app target only — command-line-wide provisioning args leak into SPM
       dependency targets and fail the build.
6. [x] **Ship script**: adapt `iOSnative/scripts/ship-naviadmin.sh` to
       `scripts/ship.sh` here. Flow: source `api-key.env` → unlock keychain →
       bump `CURRENT_PROJECT_VERSION` in `project.yml` → `xcodegen generate` →
       archive (`Release`, `generic/platform=iOS`,
       `OTHER_CODE_SIGN_FLAGS="--keychain <path>"`, `-allowProvisioningUpdates=NO`
       — hard failures beat silent portal round-trips) → export → `xcrun altool
       --upload-app` → print Delivery UUID. Keep NaviAdmin's PlistBuddy check
       that the archive really contains the bumped build number.
7. [x] ~~Decide the Mac story~~ — **resolved 2026-10-20**: no separate Mac
       pipeline needed. iOS TestFlight builds install and run via TestFlight on
       the Mac too (Olivier runs Amperfy from TestFlight on his Mac), so the
       iOS pipeline above captures the Mac for free.

## Every session that ships

- [ ] `source ~/sites/navidromClient/spike/.signing/api-key.env`
- [ ] Unlock the build keychain (command in testflight-pipeline.md §One-time
      environment; password file lives in `.signing/`).
- [ ] Sanity: `security find-identity -v -p codesigning <keychain>` shows the
      Apple Distribution identity; the profile is present in
      `~/Library/MobileDevice/Provisioning Profiles/`.

## Every upload

- [ ] `CFBundleVersion` (`CURRENT_PROJECT_VERSION`) strictly monotonic —
      Apple rejects redundant build numbers at the *altool* stage
      (ITMS-90189), after archive/export already "succeeded".
      `MARKETING_VERSION` may stay put.
- [ ] `ITSAppUsesNonExemptEncryption: false` — already in our `project.yml` ✓.
- [ ] **Delivery UUID ≠ delivered.** Processing is async: poll the ASC API for
      `processingState: VALID` (`PROCESSING` = wait; `INVALID`/`FAILED` =
      investigate, don't blind-retry). `iOSnative/scripts/asc-builds.py
      <bundle-id>` lists recent builds.

## Watch-outs (from the common-failure table, condensed)

- Profile expiry: the existing spike profiles expire **2027-04-10**; ours will
  get its own clock from creation.
- `xcodebuild` hanging on `builtin-RegisterExecutionPolicyException`:
  first-run Gatekeeper registration — let it finish once.
- Use the `release-version` skill for bumps; CHANGELOG entry per build
  (NaviAdmin bundles its CHANGELOG into the app — nice pattern if we want an
  in-app "what's new" later).
