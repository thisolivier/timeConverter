# __APP_NAME__ for Android

Kotlin + Jetpack Compose, phones, sideloaded from GitHub Releases through
Obtainium (no Google Play).

## Architecture

```
android/
  core/   plain Kotlin/JVM library: all logic, no Android imports, JVM tests in seconds
  app/    the Compose shell: one activity over :core
  gradle/libs.versions.toml   every tool and library version, pinned
```

Keep logic in `core`; `app` renders state and nothing else. Versions come from
`../version.properties` (versionCode = BUILD_NUMBER, versionName =
VERSION_NAME.BUILD_NUMBER, the shape Obtainium needs).

## Working patterns

```bash
scripts/setup-android.sh --check      # toolchain report (drop --check to install)
scripts/test-android.sh               # JVM tests, no emulator
scripts/run-android.sh --screenshot shot.png   # headless emulator, debug build
scripts/run-android.sh --release      # the signed, R8-shrunk release build
scripts/run-android.sh --stop
scripts/setup-android-signing.sh      # once: the release key (back it up!)
scripts/ship-android.sh --dry-run     # everything but the publish
scripts/ship-android.sh               # next build number -> GitHub Release
```

Releases are tagged `android-<versionName>`; the phone-side steps are in
`docs/android-install.md`.

## Main components

- `core/.../Greeting.kt`: placeholder logic, pinned by `GreetingTest` and
  asserted on screen by the release smoke. Replace with the real core.
- `app/.../MainActivity.kt`: the activity; the `initialInput` extra drives the
  screen to a state for screenshots.
