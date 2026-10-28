#!/usr/bin/env bash
# android-env.sh — the Android toolchain this machine uses. Sourced by every
# Android script so nothing depends on the user's shell profile.
#
# Everything here was installed by scripts/setup-android.sh:
#   JDK 17        brew openjdk@17 (AGP 9 needs 17+; brew's openjdk 26 also works)
#   SDK           ~/Library/Android/sdk via brew's android-commandlinetools cask
#   Gradle        the wrapper in TimeConverterAndroid/ (9.6.1), not brew's
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"

ANDROID_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../TimeConverterAndroid" && pwd)"
ANDROID_APP_ID="dev.thisolivier.timeconverter"
ANDROID_AVD_NAME="timeconverter-api36"
ANDROID_SYSTEM_IMAGE="system-images;android-36;google_apis;arm64-v8a"
