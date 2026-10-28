#!/usr/bin/env bash
# setup-android.sh: idempotent install of everything the Android lane needs.
#
#   scripts/setup-android.sh          # install what is missing, create the AVD
#   scripts/setup-android.sh --check  # report only, change nothing
#
# Safe to re-run; each step is a no-op when already done. It accepts the SDK
# licences (`yes |`) because the brew cask does not. Re-run after `brew
# upgrade` moves the command-line tools.
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true
MISSING=0

step() { printf '\n== %s\n' "$1"; }
missing() { echo "MISSING $1"; MISSING=$((MISSING + 1)); }

step "Homebrew: openjdk@17, gradle (wrapper bootstrap only), gh, android-commandlinetools"
for formula in openjdk@17 gradle gh; do
  if brew list --formula "$formula" >/dev/null 2>&1; then echo "ok  $formula"
  elif $CHECK_ONLY; then missing "$formula"
  else brew install "$formula"; fi
done
if brew list --cask android-commandlinetools >/dev/null 2>&1; then echo "ok  android-commandlinetools"
elif $CHECK_ONLY; then missing "android-commandlinetools"
else brew install --cask android-commandlinetools; fi

step "SDK packages in $ANDROID_HOME"
PACKAGES=(
  "cmdline-tools;latest"       # the SDK's own avdmanager/sdkmanager (see android-env.sh)
  "platform-tools"
  "emulator"
  "platforms;android-37.0"     # compileSdk 37: what the current Compose BOM demands
  "platforms;android-36"       # targetSdk 36 and the emulator image's API level
  "build-tools;36.0.0"
  "$ANDROID_SYSTEM_IMAGE"
)
# Before cmdline-tools;latest exists, only brew's sdkmanager is on PATH.
SDKMANAGER="$(command -v sdkmanager || true)"
if $CHECK_ONLY; then
  for package in "${PACKAGES[@]}"; do
    [[ -d "$ANDROID_HOME/${package//;//}" ]] && echo "ok  $package" || missing "$package"
  done
else
  [[ -n "$SDKMANAGER" ]] || { echo "sdkmanager not found; is android-commandlinetools installed?"; exit 1; }
  mkdir -p "$ANDROID_HOME"
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --install "${PACKAGES[@]}"
fi

step "Virtual device $ANDROID_AVD_NAME (Pixel 8, API 36, arm64)"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"   # never brew's, see android-env.sh
if [[ -x "$AVDMANAGER" ]] && "$AVDMANAGER" list avd -c 2>/dev/null | grep -qx "$ANDROID_AVD_NAME"; then
  echo "ok  $ANDROID_AVD_NAME"
elif $CHECK_ONLY; then
  missing "AVD $ANDROID_AVD_NAME"
else
  echo no | "$AVDMANAGER" create avd --name "$ANDROID_AVD_NAME" --package "$ANDROID_SYSTEM_IMAGE" --device pixel_8
  "$AVDMANAGER" list avd -c | grep -qx "$ANDROID_AVD_NAME" || { echo "AVD creation failed silently"; exit 1; }
fi

step "Gradle wrapper $GRADLE_VERSION in $ANDROID_PROJECT_DIR"
if [[ -x "$ANDROID_PROJECT_DIR/gradlew" ]]; then
  echo "ok  gradlew present"
elif $CHECK_ONLY; then
  missing "gradlew (run without --check to generate it)"
else
  # Generated in an empty directory so brew's gradle (any version) never
  # configures the real build, which needs Gradle $GRADLE_VERSION for AGP 9.
  WRAPPER_SCRATCH="$(mktemp -d)"
  touch "$WRAPPER_SCRATCH/settings.gradle.kts"
  (cd "$WRAPPER_SCRATCH" && gradle wrapper --gradle-version "$GRADLE_VERSION" --distribution-type bin -q)
  cp "$WRAPPER_SCRATCH/gradlew" "$WRAPPER_SCRATCH/gradlew.bat" "$ANDROID_PROJECT_DIR/"
  mkdir -p "$ANDROID_PROJECT_DIR/gradle/wrapper"
  cp "$WRAPPER_SCRATCH"/gradle/wrapper/* "$ANDROID_PROJECT_DIR/gradle/wrapper/"
  rm -rf "$WRAPPER_SCRATCH"
  echo "generated gradlew (commit gradlew, gradlew.bat and gradle/wrapper/)"
fi
if [[ -x "$ANDROID_PROJECT_DIR/gradlew" ]]; then
  (cd "$ANDROID_PROJECT_DIR" && ./gradlew --version 2>/dev/null | grep -E '^(Gradle|Launcher JVM)') || missing "runnable gradlew"
fi

step "GitHub CLI login (needed only to publish)"
gh auth status >/dev/null 2>&1 && echo "ok  gh logged in" || echo "not logged in: run gh auth login -h github.com before the first real ship"

echo
if [[ $MISSING -gt 0 ]]; then echo "$MISSING item(s) missing."; exit 1; fi
echo "Done. Next: scripts/test-android.sh, then scripts/run-android.sh --screenshot shot.png"
