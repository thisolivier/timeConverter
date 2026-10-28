# Android distribution without Google Play

Researched 2026-10-28, after Olivier declined the Play Console onboarding
(identity-verification steps beyond the fee). Backlog item 24e. Scope: get
builds onto Olivier's own phone, remote from the build Mac, repeatably, with
no Google developer account of any kind. One to a few phones, not the public.

## The constraint that shapes everything: developer verification

Google's "developer verification" makes certified Android devices (Android 7+)
refuse apps from unverified developers even when sideloaded. Status today:

- **Enforced since 30 Sep 2026 in Brazil, Indonesia, Singapore and Thailand
  only**, and there only for installs through participating stores. Google's
  own FAQ: direct sideloads are not covered "yet". UK/EU dates are unpublished;
  Google says "expanded globally in 2027".
- **Installs over `adb` are exempt**, now and after the global rollout. No
  account, no one-day wait, nothing to register.
- **The "advanced flow"** (Aug 2026) lets a power user keep sideloading
  unregistered apps: developer options on, a coaching-scam check, reboot,
  24-hour wait, biometric confirm. Enable for 7 days or indefinitely; every
  install still shows "Install anyway". Turn it off later and updates to
  unregistered apps fail.
- **The free "limited distribution" account** (20 devices, no ID) still wants a
  Google payments profile with legal name and address, plus a per-device
  QR handshake. Assumed to fall under the steps Olivier won't do.

So: anything that goes through `adb` is clean forever. Anything the phone
installs itself (browser, Files, Obtainium) is fine in the UK today and needs
the one-time advanced flow once enforcement arrives.

Sources: developer.android.com/developer-verification (+ `/guides/faq`,
`/guides/limited-distribution`), the Android Developers blog post of 18 Jun
2026, developer.android.com/tools/adb (updated 2026-09-25).

## Routes, ranked for this setup

The build Mac (`mistymacmini`, 100.110.206.54) is already on Olivier's
tailnet. The Android phone is not yet; every route below starts with
installing the Tailscale app on it.

### 1. Wireless `adb` over Tailscale — recommended primary

`run-android.sh` already drives an emulator through `adb`; a phone on the
tailnet is just another serial. This gives the full QA loop remotely:
install, launch with `--es initialInput`, screenshots, logcat, uninstall.

- One-time: Developer options → Wireless debugging → "Pair device with
  pairing code". Olivier reads the code and `ip:port` to me; I run
  `adb pair 100.x.y.z:PAIRPORT CODE`. Pairing persists until revoked.
- Per session: Wireless debugging shows a *connect* port that changes each
  time it is re-enabled. Olivier reads it out; I run
  `adb connect 100.x.y.z:CONNECTPORT`. Android 16 also switches wireless
  debugging off when Wi-Fi drops or the adb server goes away, so expect to
  re-read the port after a day away.
- Needs the phone on Wi-Fi (wireless debugging does not run over mobile data)
  and an inbound tailnet connection to the phone. Several people report this
  working on Android 16 Pixels (tailscale/tailscale#1990 and others); Tailscale
  has no official doc on inbound to Android. Verify on first try, that is the
  only real risk.
- No mDNS across the tailnet, so `adb mdns services` finds nothing; use the
  explicit `ip:port` form.

Tooling this implies: `scripts/run-android.sh --device 100.x.y.z:PORT`
(skip the emulator boot, target that serial) and a tiny `scripts/pair-phone.sh`
wrapper. Half a day including the first live test with Olivier.

### 2. A signed APK served on the tailnet — recommended secondary

For days when nobody wants to read a port out loud. `tailscale serve` can
publish a directory over HTTPS on the tailnet with a real certificate:

```
tailscale serve --bg --set-path /android /Users/olivier/sites/timeConvertor/TimeConverterAndroid/dist
```

The phone's browser opens `https://mistymacmini.<tailnet>.ts.net/android/`
and taps the APK. Needs MagicDNS + HTTPS certificates enabled once in the
Tailscale admin console (a click, no payment). The ship script copies the
signed APK plus a one-line `index.html` into `dist/`.

Optional on top: **Obtainium** (github.com/ImranR98/Obtainium, v1.7.3 on
2026-10-25) with its "HTML" source pointed at that page. It then notifies
and installs updates itself, which makes this a real update channel. It also
takes GitHub Releases, with a token for private repos; our repo would work,
but the tailnet page is one fewer external moving part.

Phone side, first time: allow "install unknown apps" for the browser (or
Obtainium), accept the Play Protect "unknown developer" warning via More
details → Install anyway. After UK enforcement arrives: the advanced flow
once.

### 3. Taildrop

`tailscale file cp app-release.apk <phone>:` lands in the phone's Downloads
with a notification; tap to install. Zero setup beyond Tailscale, fully
manual, still alpha, and same phone-side prompts as route 2. Fine as a
fallback, not a pipeline.

### Rejected

- **Firebase App Distribution**: free and needs only a Google account, but it
  is Google tooling for no gain over route 2.
- **Self-hosted F-Droid repo** (`fdroidserver`): correct answer for many
  phones, overkill for one.
- **Limited distribution account**: see above; only if the advanced flow ever
  becomes unacceptable.

## Signing

A sideloaded app needs nothing but a key we generate ourselves:

- `keytool -genkeypair` into `~/.config/timeconverter/android-release.jks`,
  password in `~/.config/timeconverter/android-release.properties` (both
  outside the repo, `.gitignore` already excludes `local.properties`; the new
  file lives outside the tree anyway). `app/build.gradle.kts` grows a
  `signingConfigs.release` that reads that file and skips signing when it is
  absent, so CI and fresh clones still build.
- **Every update must be signed with the same key** or Android refuses with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and the only way out is uninstall.
  Lose the key and the installed app can never be updated. Back the keystore
  up somewhere that is not this Mac.
- **If Play ever happens**: upload *this* key through the PEPK tool when
  enrolling in Play App Signing. If Play generates its own key, Play builds
  will not install over the sideloaded copy. Any future Android Developer
  Console registration also wants this key to claim the package name.
- `isMinifyEnabled = true` is already on for release; the first signed build
  should be smoke-tested on the emulator before the phone, since R8 has not
  run against this app yet.

## Plan for 24e

1. Signing config + keystore generation (`scripts/setup-android-signing.sh`,
   idempotent, prints the backup reminder).
2. `scripts/ship-android.sh <build>`: `assembleRelease`, `apksigner verify`,
   copy to `dist/` with `index.html`, print the tailnet URL. Build number from
   `project.yml` like the Apple lanes.
3. `run-android.sh --device <serial>` plus `pair-phone.sh`.
4. First live session with Olivier (Group B in `android-plan.md`): Tailscale
   on the phone, pairing, one install by each route, note what the Play
   Protect prompt looked like on his Android version.
5. Then backlog item 28, the greenfield-setup skill, written against a
   pipeline that has reached a real phone.

## Not verified

- Inbound tailnet connections to the Android Tailscale client, officially.
- When in 2027 the UK/EU enforcement lands.
- The exact Play Protect bypass wording on Android 16.
