#!/usr/bin/env bash
# setup-android.sh — idempotent install of everything the Android lane needs.
#
# Safe to re-run; each step is a no-op when already done. The only manual part
# is the SDK licence acceptance, which this script performs (`yes |`) because
# the brew cask does not. Run once on a fresh machine, or after `brew upgrade`
# moves the command-line tools.
#
#   scripts/setup-android.sh          # install SDK packages, create the AVD
#   scripts/setup-android.sh --check  # report only
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

step() { printf '\n== %s\n' "$1"; }

step "Homebrew packages (openjdk@17, android-commandlinetools)"
for formula in openjdk@17; do
  brew list --formula "$formula" >/dev/null 2>&1 && echo "ok  $formula" || { $CHECK_ONLY && echo "MISSING $formula" || brew install "$formula"; }
done
brew list --cask android-commandlinetools >/dev/null 2>&1 && echo "ok  android-commandlinetools" || { $CHECK_ONLY && echo "MISSING android-commandlinetools" || brew install --cask android-commandlinetools; }

step "SDK packages in $ANDROID_HOME"
PACKAGES=(
  "cmdline-tools;latest"
  "platform-tools"
  "emulator"
  "platforms;android-37.0"     # compileSdk 37 — what the current Compose BOM demands
  "platforms;android-36"       # targetSdk 36 and the emulator image's API level
  "build-tools;36.0.0"
  "$ANDROID_SYSTEM_IMAGE"
)
if $CHECK_ONLY; then
  sdkmanager --sdk_root="$ANDROID_HOME" --list_installed 2>/dev/null | grep -E 'platforms|build-tools|system-images|emulator|platform-tools' || true
else
  mkdir -p "$ANDROID_HOME"
  yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null
  sdkmanager --sdk_root="$ANDROID_HOME" --install "${PACKAGES[@]}"
fi

step "Virtual device $ANDROID_AVD_NAME (Pixel 8, API 36, arm64)"
if avdmanager list avd -c 2>/dev/null | grep -qx "$ANDROID_AVD_NAME"; then
  echo "ok  $ANDROID_AVD_NAME"
elif $CHECK_ONLY; then
  echo "MISSING $ANDROID_AVD_NAME"
else
  echo no | avdmanager create avd --name "$ANDROID_AVD_NAME" --package "$ANDROID_SYSTEM_IMAGE" --device pixel_8
fi

step "Gradle wrapper"
(cd "$ANDROID_PROJECT_DIR" && ./gradlew --version 2>/dev/null | grep -E '^(Gradle|Launcher JVM)' || echo "wrapper not runnable")
echo
echo "Done. Next: scripts/test-android.sh, then scripts/run-android.sh"
