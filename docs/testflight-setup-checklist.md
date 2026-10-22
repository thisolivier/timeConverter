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
3. [x] **Create an App Store distribution provisioning profile** for the bundle
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

## Verified in practice (2026-10-21)

Build 3 installed and ran from TestFlight on both iPhone and Mac (Olivier
confirmed). The Mac-for-free Catalyst theory holds for this app's own
pipeline, not just Amperfy's.

---

## macOS train (backlog items 12b → 16)

Item 7 above — "no separate Mac pipeline needed" — is **half right and was
retired on 2026-10-22**. What TestFlight delivers on the Mac today is the *iOS*
binary running in the compatibility runtime. That is genuinely fine for the app
as it was, and that lane is untouched; it just cannot carry a menu bar, a global
hotkey or anything else built against the macOS SDK. So the Mac gets its own
lane into the **same app record** (`6825044484`), as a second platform train.

**Revised 2026-10-22 (same day), for the native two-target restructure
(backlog item 16).** This section was first written for a Mac *Catalyst*
archive. Catalyst is retired as the Mac story: the Mac is now its own native
target, `TimeConverterMac` (`MenuBarExtra`, ⌃⌥T, no Dock icon). Everything below
reflects the native lane. The two substantive changes to the portal errand:

- the profile **type** is plain **"Mac"**, not "Mac Catalyst";
- there is **one** profile to create, not two — the Control Center extension is
  iOS-only (no Control Center on the Mac), so the native Mac app embeds no
  extension and `dev.thisolivier.timeconverter.controls` needs nothing here.

The installer-certificate step transfers verbatim: it is a property of the macOS
App Store, not of Catalyst.

| | iOS lane | macOS lane |
|---|---|---|
| script | `scripts/ship.sh <n>` | `scripts/ship-mac.sh <n>` |
| target | `TimeConverter` | `TimeConverterMac` |
| archive | `generic/platform=iOS` | `generic/platform=macOS` |
| product | `.ipa` | `.pkg` (an installer package) |
| upload | `altool -t ios` | `altool -t macos` |
| export options | `ExportOptions.plist` | `ExportOptions-mac.plist` |
| profiles needed | app + Controls | app only |

Both read `CURRENT_PROJECT_VERSION` from `project.yml` through the shared
`scripts/lib/version.sh`, because **macOS requires `CFBundleVersion` to increase
monotonically across *all* platform trains** (iOS does not). The iOS train has
already consumed build 5, so the first Mac upload must be **6 or higher**, and a
number burned on a rejected Mac upload is not recoverable.

### What the archive actually demands (not guessed — measured)

Dry-run on 2026-10-22, `SKIP_PREFLIGHT=1 scripts/ship-mac.sh --validate-only`
against the native target. It got as far as signing and stopped, naming exactly
one missing artifact. Verbatim:

```
/Users/olivier/sites/timeConvertor/TimeConverter.xcodeproj: error: No profile
for team 'CNHB9B5GX6' matching 'TimeConverter Mac App Store' found: Xcode
couldn't find any provisioning profiles matching 'CNHB9B5GX6/TimeConverter Mac
App Store'. Install the profile (by dragging and dropping it onto Xcode's dock
item) or select a different one in the Signing & Capabilities tab of the target
editor. (in target 'TimeConverterMac' from project 'TimeConverter')
```

One demand, one target, one profile name. That is the portal list below, and it
is why the Catalyst-era "TimeConverter Controls Mac App Store" step is gone
rather than deferred.

### Olivier's portal errand (the final list)

Nothing in the local repo is waiting on anything else — `scripts/ship-mac.sh`
stops in preflight and prints this same list until these exist. All of it is at
developer.apple.com, team **CNHB9B5GX6**.

1. [ ] **Certificates → + → "Mac Installer Distribution"**. Upload the existing
       CSR at `~/sites/navidromClient/spike/.signing/distribution.csr` (same
       key as the Apple Distribution cert — no need to make a new one). Save
       the `.cer` next to it as `installer-distribution.cer`, then import it:
       `security import … -k ~/Library/Keychains/spike-build.keychain-db`.
       *Why a whole new certificate:* the macOS App Store product is a signed
       **installer package**, and installer certs have different OIDs from
       code-signing certs — per DTS, "not interchangeable in any way". The
       Apple Distribution cert signs the app inside the package; it cannot sign
       the package. **Unchanged by the restructure.**
2. [ ] **Identifiers → `dev.thisolivier.timeconverter` → enable macOS / Mac**,
       so a macOS profile can be issued against the SAME App ID. If asked,
       choose **"Use existing Mac App ID"** — never "Automatically create an
       identifier", which mints a `maccatalyst.`-prefixed App ID we do not want
       (and which the native target would not match anyway). The bundle id stays
       exactly as it is on iOS; that shared id is what makes the Mac app the
       macOS train of 6825044484 rather than a second app.
       (Skip if the App ID already shows up in step 3's menu.)
       **Only the app's App ID** — nothing for
       `dev.thisolivier.timeconverter.controls`.
3. [ ] **Profiles → + → Distribution → "Mac App Store Connect"**, Profile Type
       **"Mac"** (NOT "Mac Catalyst"), App ID
       `dev.thisolivier.timeconverter`, certificate **Apple Distribution**,
       named *exactly*:
       **`TimeConverter Mac App Store`**
4. [ ] **Download the `.provisionprofile`.** Save it to
       `~/sites/navidromClient/spike/.signing/` as
       `TimeConverter_Mac_App_Store.provisionprofile`, and install it into
       **both**
       `~/Library/MobileDevice/Provisioning Profiles/` and
       `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
       (Xcode 16+ nominally uses the latter; this machine's working iOS
       profiles live in the former, and Apple staff have cited both).
5. [x] ~~App Store Connect: add the macOS platform to app 6825044484~~ —
       **already done, nothing to click.** Checked against the ASC API on
       2026-10-22: the record already carries a `MAC_OS` `appStoreVersion`
       (1.0, PREPARE_FOR_SUBMISSION) alongside the `IOS` one. Only the *iOS*
       `preReleaseVersion` exists, and that is the TestFlight train — it appears
       for macOS on its own once the first macOS build finishes processing.
6. [x] ~~Create a second macOS profile for the Controls extension~~ —
       **DROPPED with the Catalyst retirement.** The native Mac app embeds no
       extension, so `TimeConverter Controls Mac App Store` is not needed and
       should not be created.

Steps 1 and 4 end with files on disk, so they are not purely browser work.

### What the macOS lane adds to the build itself

- **App Sandbox is mandatory** for the Mac App Store, enforced mechanically at
  ingestion (ITMS-90296 enumerates every executable missing
  `com.apple.security.app-sandbox`). The native archive has exactly one
  executable, so there is exactly one entitlements file —
  `TimeConverterMac/TimeConverter-macOS.entitlements` — wired in through
  `CODE_SIGN_ENTITLEMENTS` in the Mac target's Release config only. Debug,
  `scripts/test.sh` and `scripts/run-mac.sh` are unsandboxed;
  `scripts/run-mac.sh --sandboxed` opts in when you want to exercise the
  sandbox locally. (The Catalyst lane needed two entitlements files and
  `[sdk=macosx*]` conditions on a shared target; both are gone.)
- **Sandbox contents are deliberately one line.** No network entitlement (the
  app never makes a request), no file-access entitlement (the only file read is
  in its own bundle), and nothing for ⌃⌥T — Carbon `RegisterEventHotKey`
  works from a sandboxed App Store app with no entitlement and no TCC grant,
  because the WindowServer delivers only the one pre-declared chord.
- **`LSUIElement` is load-bearing and asserted.** The Mac product is a menu-bar
  utility; `ship-mac.sh` refuses to upload an archive without it, because
  shipping that key by accident gives the user a Dock icon and no window.
- **The loadable-bundle question is retired, not answered.** The Catalyst lane
  carried one genuine unknown — whether ingestion accepts a macOS-SDK `.bundle`
  embedded in `Contents/PlugIns`, which Apple DTS called unsupported three
  times. The native archive contains no such bundle, so the question no longer
  applies to anything we ship.

### Still worth asking before burning a build number

```
scripts/ship-mac.sh --validate-only
```

`altool --validate-app` runs the same ITMS validation as an upload and delivers
nothing, so it consumes **no build number** and leaves no row in the build list
— which matters here precisely because macOS build numbers are unrecoverable.
A pass is not a promise about App Review, only about ingestion. Record any
failure's text here verbatim.
