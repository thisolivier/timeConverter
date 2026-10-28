#!/usr/bin/env bash
# android-env.sh: the Android toolchain and project constants. Sourced by every
# Android script so nothing depends on the user's shell profile. Also safe to
# `source` from an interactive zsh to get adb/emulator on PATH.
#
# Installed by scripts/setup-android.sh:
#   JDK 17   brew openjdk@17 (AGP 9 needs 17+)
#   SDK      ~/Library/Android/sdk, bootstrapped by brew's android-commandlinetools
#   Gradle   the wrapper in android/ (GRADLE_VERSION), not brew's gradle
#
# The SDK's own cmdline-tools/latest/bin goes FIRST on PATH: brew's cask puts an
# older avdmanager in /opt/homebrew/bin that silently fails to create AVDs for
# current system images.
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$JAVA_HOME/bin:$PATH"

# ${BASH_SOURCE[0]:-$0}: BASH_SOURCE is empty when zsh sources this file.
ANDROID_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ANDROID_REPO_DIR="$(cd "$ANDROID_SCRIPTS_DIR/.." && pwd)"
ANDROID_PROJECT_DIR="$ANDROID_REPO_DIR/android"
ANDROID_VERSION_FILE="$ANDROID_REPO_DIR/version.properties"

ANDROID_APP_NAME="__APP_NAME__"
ANDROID_APP_ID="__APPLICATION_ID__"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-__GITHUB_REPOSITORY__}"
GRADLE_VERSION="9.6.1"
ANDROID_AVD_NAME="${ANDROID_AVD_NAME:-__APP_NAME__-api36}"
ANDROID_SYSTEM_IMAGE="system-images;android-36;google_apis;arm64-v8a"

# The release key lives outside the repo. Read by app/build.gradle.kts too
# (same default), so override it for both by exporting it.
export ANDROID_SIGNING_PROPERTIES="${ANDROID_SIGNING_PROPERTIES:-$HOME/.config/$ANDROID_APP_ID/android-release.properties}"

# Newest installed build-tools (apksigner, aapt2), for the release lane.
ANDROID_BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)"
