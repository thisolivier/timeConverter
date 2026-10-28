# Android distribution without Google Play

Researched 2026-10-28, after Olivier declined the Play Console onboarding
(identity-verification steps beyond the fee). Backlog item 24e.

**Who this is for:** Olivier's partner's phone. Not a developer, not on the
tailnet, not someone who will toggle developer options or read ports out
loud. Requirements: install once with ordinary phone steps, then be *told*
when an update exists and tap once to get it. QA stays on the headless
emulator; nothing here is about driving the phone from the Mac.

## The constraint that shapes everything: developer verification

Google's "developer verification" makes certified Android devices (Android 7+)
refuse apps from unverified developers even when sideloaded. Status today:

- **Enforced since 30 Sep 2026 in Brazil, Indonesia, Singapore and Thailand
  only**, and there only for installs through participating stores. Google's
  own FAQ: direct sideloads are not covered "yet". UK/EU dates are unpublished;
  Google says "expanded globally in 2027".
- **The "advanced flow"** (Aug 2026) lets a phone keep installing unregistered
  apps: developer options on, a scam-coaching check, reboot, 24-hour wait,
  biometric confirm. Enable for 7 days or indefinitely; each install still
  shows "Install anyway". Turn it off later and updates to unregistered apps
  fail.
- **Installs over `adb` are exempt**, but that only helps a developer's own
  phone, so it is irrelevant here.
- **The free "limited distribution" account** (20 devices, no ID) still wants a
  Google payments profile with legal name and address, plus a per-device
  QR handshake. Assumed to fall under the steps Olivier won't do.

What this means for the partner's phone: every route below works today with
the usual "install unknown apps" permission and a Play Protect warning. When
UK enforcement lands in 2027 the phone needs the advanced flow **once**, set
to "indefinitely", ideally with Olivier beside it. Budget an evening for that
when the time comes; nothing to do now.

Sources: developer.android.com/developer-verification (+ `/guides/faq`,
`/guides/limited-distribution`), the Android Developers blog post of 18 Jun
2026, developer.android.com/tools/adb (updated 2026-09-25).

## Routes, ranked for a partner's phone

### 1. Obtainium watching GitHub Releases — recommended

The repo is public (`github.com/thisolivier/timeConverter`), so a GitHub
Release with the signed APK attached is a free, durable, public download URL
with zero hosting on our side.

[Obtainium](https://github.com/ImranR98/Obtainium) (actively maintained,
v1.7.3 on 2026-10-25) is a small app that watches a URL and does the thing a
store does: notifies on a new version, downloads, hands the APK to the system
installer. Add the repo URL once; after that updates are a notification and a
tap.

- **Our side per release**: `scripts/ship-android.sh <build>` runs
  `assembleRelease`, verifies the signature, and `gh release create
  android-<build>` with the APK attached. Shares the build number with the
  Apple lanes via `project.yml`. Built 2026-10-28; the tag is actually
  `android-<versionName>` (e.g. `android-0.1.0.17`), see "Plan for 24e".
- **Partner's phone, once** (ten minutes, best done together on a call):
  1. Install Obtainium itself: browser → its GitHub releases page → tap the
     APK → allow "install unknown apps" for the browser → Play Protect
     "unknown developer" → More details → Install anyway.
  2. In Obtainium, "Add app", paste `https://github.com/thisolivier/timeConverter`,
     tick "Include prereleases" off, leave the rest default. Allow Obtainium to
     install unknown apps when asked.
  3. Install Time Converter from inside Obtainium.
- **Behaviour after that**: Obtainium checks in the background and raises a
  notification when a new release appears; tapping installs it. Updates land
  over the old version with data intact because the key is the same.
- **Caveats**: Obtainium's install still goes through the system installer, so
  Play Protect may show its warning on each update until the developer is
  known to it. The 2027 advanced-flow note above applies.

If the source repo ever goes private, a separate public `timeConverter-releases`
repo holding only APKs keeps this route intact.

### 2. Plain link in the browser, no Obtainium

Same GitHub Release, opened in the browser, APK tapped. Nothing to install
beyond the app. The gap is updates: nobody is told. Closable later with a
small in-app check, the app fetching a one-line `latest.json` from the
releases and showing an "Update available" line that opens the download.
That is real feature work (network call, a privacy sentence, tests) and is
the fallback if Obtainium annoys in practice, not the first move.

### 3. Tailnet routes (`tailscale serve`, Taildrop)

Would mean putting Tailscale on the partner's phone and adding them as a
tailnet user. A VPN app running permanently on someone else's phone to
receive an app update is the wrong trade. Dropped.

### Rejected

- **Firebase App Distribution**: designed for exactly this (tester invites,
  update notifications) but requires Google accounts on both ends. Out.
- **Self-hosted F-Droid repo** (`fdroidserver`): the F-Droid client would do
  what Obtainium does, with a repo to maintain. Overkill for one phone.
- **Wireless `adb` over Tailscale**: the right answer for a developer's own
  phone; useless for a partner.

## Signing

A sideloaded app needs nothing but a key we generate ourselves:

- `keytool -genkeypair` into `~/.config/timeconverter/android-release.jks`,
  password in `~/.config/timeconverter/android-release.properties`, both
  outside the repo. `app/build.gradle.kts` grows a `signingConfigs.release`
  that reads that file and skips signing when it is absent, so fresh clones
  still build.
- **Every update must be signed with the same key** or Android refuses with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only way out is uninstall and
  lose data. Lose the key and the installed app can never be updated. The
  keystore needs a backup off this Mac.
- **If Play ever happens**: upload *this* key through the PEPK tool when
  enrolling in Play App Signing, or store builds will not install over the
  sideloaded copy. Any future developer-console registration also wants this
  key to claim the package name.
- `isMinifyEnabled = true` is already on for release; the first signed build
  gets smoke-tested on the emulator (`run-android.sh --release`) before it is
  published, since R8 has not run against this app yet.

## Plan for 24e

1. Signing config + `scripts/setup-android-signing.sh` (idempotent, prints the
   backup reminder).
2. `scripts/ship-android.sh <build>`: release build, `apksigner verify`,
   emulator smoke install, `gh release create` with the APK and a short note.
3. A `docs/android-install.md` page in plain language for the partner: the
   three steps above with screenshots from the emulator, so the first install
   can happen without Olivier on the call if needed.
4. First real install on the partner's phone (Group B in `android-plan.md`).
   Note what Play Protect said on their Android version.
5. Then backlog item 28, the greenfield-setup skill, written against a
   pipeline that has reached a real phone.

**Status 2026-10-28:** steps 1–3 done (build 17 published,
`docs/android-install.md` written from an emulator run of exactly these
steps). Naming changed on contact with Obtainium's source: it takes the
release *tag* as the version and compares it with the installed
`versionName`, so `versionName` became `MARKETING_VERSION.build` and the tag
`android-<versionName>`. Step 4 is next.

## Blockers for Olivier

- `gh auth login`: resolved, `gh` is logged in.
- Back up the release key (`~/.config/timeconverter/android-release.jks` and
  `.properties`) off this Mac.
- Step 4, the install session with the partner.

## Not verified

- When in 2027 the UK/EU enforcement lands.
- The exact Play Protect wording on the partner's Android version. The
  emulator (Google APIs image with Play Store, no Google account signed in)
  showed no Play Protect prompt at all, for Obtainium or for Time Converter.
