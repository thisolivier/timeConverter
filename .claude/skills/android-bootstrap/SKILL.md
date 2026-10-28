---
name: android-bootstrap
description: Bootstrap a Kotlin + Jetpack Compose Android phone app on a Mac that has never built Android - toolchain install, two-module Gradle project, headless-emulator QA loop, own release key, and a ship script that publishes a signed APK to GitHub Releases for install and updates through Obtainium (no Google Play, no Google developer account). Use when the user says "set up an Android project", "Android build", "Kotlin/Compose app", "ship an APK to GitHub Releases", or mentions Obtainium.
---

# Android App Bootstrap (Kotlin + Compose, GitHub Releases + Obtainium)

The Android sibling of `ios-universal-bootstrap`. It takes a Mac from zero to
a signed APK on a phone without Google Play, without rediscovering the lessons
of the first run. Proven end to end on `sites/timeConvertor` (2026-10-28):
build 17 went to GitHub Releases, Obtainium installed it and updated 16 → 17 in
place. The templates were then re-verified from scratch in a throwaway project.

## Decisions this skill bakes in

- **Native Kotlin + Compose, two modules.** `:core` is a plain Kotlin/JVM
  library holding all the logic, with no Android imports, so its tests run in a
  second with no emulator. `:app` is a thin Compose shell (one activity).
- **Pinned toolchain** (`android/gradle/libs.versions.toml`): AGP 9.4.1, Kotlin
  2.4.21, Compose BOM 2026.09.00, Gradle wrapper 9.6.1, JDK 17 (brew
  `openjdk@17`), compileSdk 37, targetSdk 36, minSdk 26. SDK under
  `~/Library/Android/sdk`, emulator image Pixel 8 / API 36 / arm64.
- **Headless emulator QA.** The Mac may be driven over ssh. The emulator runs
  `-no-window`, and you look at it through `--screenshot` PNGs and
  `uiautomator dump` text.
- **Distribution = GitHub Releases + Obtainium.** No Play Console, no Google
  account. Releases are signed with our own key, and the phone adds the repo
  URL to Obtainium once, then gets update notifications.
- **Version source: `version.properties`** at the repo root (`VERSION_NAME`,
  `BUILD_NUMBER`), read by `app/build.gradle.kts` and bumped by the ship
  script. `versionCode` = build; `versionName` = `VERSION_NAME.BUILD_NUMBER`
  (`0.1.0.17`); tag = `android-<versionName>`. A project with Apple lanes can
  share one number instead: point the two lookups in `app/build.gradle.kts` and
  `version_property`/`write_build_number` in `scripts/lib/android-release.sh`
  at its `project.yml` (timeConvertor does this).
- **The release key lives outside the repo**, at
  `~/.config/<applicationId>/android-release.{jks,properties}` (override with
  `ANDROID_SIGNING_PROPERTIES`). A clean clone builds release *unsigned*, with
  a warning, and the ship script refuses to publish that.

## Steps

1. **Name it first.** Pick `__APP_NAME__` (identifier-like, e.g. `TimeConverter`),
   `__APPLICATION_ID__` (`dev.thisolivier.<lowercased name>`; it can never
   change once a phone has installed the app), and `__GITHUB_REPOSITORY__`
   (`owner/repo`, **public**, since Obtainium reads its releases anonymously).
2. Copy the templates into the repo root and substitute:
   ```bash
   cp -R ~/.claude/skills/android-bootstrap/templates/. .   # or this skill's path
   grep -rl '__APP_NAME__\|__APPLICATION_ID__\|__GITHUB_REPOSITORY__' android scripts docs version.properties \
     | xargs sed -i '' -e 's/__APP_NAME__/MyApp/g' -e 's/__APPLICATION_ID__/dev.thisolivier.myapp/g' \
                       -e 's#__GITHUB_REPOSITORY__#owner/repo#g'
   ```
   Sources may stay flat in `src/main/kotlin/` (Kotlin does not require package
   directories) or move into them. Merge with existing `scripts/`/`docs/` files
   rather than overwrite them.
3. `scripts/setup-android.sh` installs brew `openjdk@17 gradle gh
   android-commandlinetools`, the SDK packages (and accepts the licences), the
   AVD `<AppName>-api36`, and the Gradle wrapper. It is idempotent, and
   `--check` reports without changing anything (exit 1 if anything is missing).
   Commit `android/gradlew*` and `android/gradle/wrapper/`.
4. `gh auth login -h github.com` if `setup-android.sh` says so. This is a
   prerequisite for publishing only.
5. `scripts/setup-android-signing.sh`, once. **Then back up both files it
   prints off the machine** (e.g. a password manager). A lost key means
   installed copies can never update again.
6. Verify before declaring done. All of these must pass, not just the first:
   - `scripts/test-android.sh`: `GreetingTest ... PASSED`, `BUILD SUCCESSFUL`.
   - `scripts/run-android.sh --input "hi" --screenshot /tmp/debug.png`, then
     read the PNG: it shows "Hello from <AppName>" and "hi".
   - `scripts/ship-android.sh --dry-run`: 7/7 steps, including "Signed by the
     release key" and "on screen: Hello from <AppName>" (the R8 release smoke).
     The dry run restores `version.properties` when it exits.
   - `scripts/run-android.sh --stop`.
7. **First real release:** commit, push, `scripts/ship-android.sh` (no
   argument = next build number), then commit the bump:
   `git commit -m "Android build <N> shipped (...)" version.properties && git push`.
8. **Phone side, for a non-technical user.** Send them
   `docs/android-install.md` (on GitHub), ideally on a call the first time:
   - Install Obtainium from `github.com/ImranR98/Obtainium/releases/latest`
     (`app-release.apk`), allowing the browser to install unknown apps.
   - At the Play Protect "unknown developer" prompt, tap **More details →
     Install anyway**.
   - In Obtainium: **+ Add**, paste `https://github.com/<owner/repo>`, leave
     "Include prereleases" off, tap **Install**, and allow Obtainium to
     install apps.
   - **Updates:** Obtainium notifies them; they tap **Update** twice and the
     app's data is kept.

   Optionally add emulator screenshots of each step to the page. Obtainium
   itself runs fine on the emulator for that.

## Gotchas (each cost real debugging time, so don't relearn them)

- **Compose BOM 2026.09 needs compileSdk 37** (the `platforms;android-37.0`
  package). targetSdk can stay at 36.
- **Brew's `android-commandlinetools` ships an old `avdmanager`** in
  `/opt/homebrew/bin` that *silently* fails to create AVDs for current images.
  `android-env.sh` puts the SDK's `cmdline-tools/latest/bin` first on PATH, and
  `setup-android.sh` calls that `avdmanager` by full path and re-checks.
- **`${BASH_SOURCE[0]:-$0}`** in `android-env.sh`: `BASH_SOURCE` is empty when
  zsh sources the file, so without the fallback every path resolves wrong.
- **AGP 9 has built-in Kotlin.** Don't apply `org.jetbrains.kotlin.android`.
  The root `kotlin-jvm` alias is what gives AGP its Kotlin version.
- **`--rerun` on the test tasks**, or a cached green run prints no per-test
  lines and you can't tell what ran.
- **Exit status through a pipe.** `gradlew | grep` hides gradle's status. Read
  `PIPESTATUS[0]` on the right of `||`, not after `|| true`: that form reads
  `true`'s status and passes failing tests (bug found while verifying this
  skill; the timeConvertor original has it).
- **Debug and release are signed by different keys**, so one won't install over
  the other (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). After a ship dry-run the
  emulator also holds a higher versionCode than the restored file
  (`INSTALL_FAILED_VERSION_DOWNGRADE`). `run-android.sh` uninstalls and retries
  on exactly those two errors and fails loudly on anything else.
- **Obtainium's version = the release TAG**, compared with the installed
  `versionName` by numeric shape. Hence the build number inside `versionName`
  and the tag `android-<versionName>`. A bare `android-17` against `0.1.0`
  silently turns its version detection off.
- **Smoke-test R8 with on-screen text, not just a screenshot.** Release builds
  minify and shrink resources, and a stripped classpath resource or reflected
  class can render a plausible but empty screen. Grow `SMOKE_EXPECTED_TEXTS`
  (and `SMOKE_INPUT`) in `ship-android.sh` with text that only appears if the
  core logic really ran. Add keep rules to `proguard-rules.pro` only when the
  smoke fails.
- **Google developer verification.** Since 30 Sep 2026, certified devices in
  BR/ID/SG/TH refuse apps from unregistered developers installed via
  participating stores. It goes global "in 2027", so UK/EU dates are
  unpublished. `adb` installs are exempt (a developer's own phone only). Once
  enforcement reaches the user's country, their phone needs the one-time
  **"advanced flow"** (developer options, a 24-hour wait, biometric confirm;
  set it to "indefinitely"). Until then, the Play Protect "Install anyway"
  prompt is the only friction. The emulator image showed no Play Protect
  prompt at all, so that wording is from Google's docs.
- **Optional pattern: cross-platform parity gate.** When the core is a port of
  another platform's core, make the ship script refuse to build unless a shared
  fixture suite ran with nothing skipped. See `scripts/lib/parity-gate.sh` in
  timeConvertor. Not templated, because it is project-specific.

## Reference projects (read-only)

- `sites/timeConvertor`: the proven instance. `TimeConverterAndroid/` (Gradle
  project, `readme.md` "Release lane"), `scripts/*android*.sh`,
  `docs/android-distribution.md` (routes considered, developer-verification
  facts, Obtainium naming), `docs/android-install.md` (the partner page with
  emulator screenshots), `docs/android-plan.md`.
- `ios-universal-bootstrap` (nakedClaude): the iOS sibling, for a project that
  ships both.
