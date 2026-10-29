#!/usr/bin/env bash
# run-android.sh — build, install and launch the app on the emulator.
#
# Headless by default, because this machine is driven over ssh: the emulator
# runs with no window and you look at it through screenshots. Pass --window on
# a machine with a display.
#
#   scripts/run-android.sh                        # boot if needed, build, install, launch
#   scripts/run-android.sh --input "12pm ET in London"   # launch with the field prefilled
#   scripts/run-android.sh --favourites "London,PST,Tokyo" --tab clocks --offset-minutes 1140
#                                                 # DEBUG only: replace favourites, open Clocks, shift the dial
#   scripts/run-android.sh --release              # the signed, R8-shrunk release APK instead of debug
#   scripts/run-android.sh --screenshot out.png   # ...then capture the screen to a PNG
#   scripts/run-android.sh --window               # emulator with a window
#   scripts/run-android.sh --stop                 # shut the emulator down
#
# First run of an emulator may trigger a macOS firewall/network prompt on the
# machine's screen — accept it once.
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"

INITIAL_INPUT=""
FAVOURITES=""
SELECTED_TAB=""
CLOCK_OFFSET_MINUTES=""
INSTALL_TASK=":app:installDebug"
SCREENSHOT=""
WINDOW_FLAGS=(-no-window)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INITIAL_INPUT="$2"; shift 2 ;;
    --screenshot) SCREENSHOT="$2"; shift 2 ;;
    --window) WINDOW_FLAGS=(); shift ;;
    --release) INSTALL_TASK=":app:installRelease"; shift ;;
    --stop) adb emu kill >/dev/null 2>&1 || true; echo "emulator stopped"; exit 0 ;;
    --favourites) FAVOURITES="$2"; shift 2 ;;
    --tab) SELECTED_TAB="$2"; shift 2 ;;
    --offset-minutes) CLOCK_OFFSET_MINUTES="$2"; shift 2 ;;
    --help|-h) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

boot_emulator_if_needed() {
  if adb devices | grep -q 'emulator-.*device$'; then
    echo "emulator already running"
    return
  fi
  echo "booting $ANDROID_AVD_NAME (headless: ${WINDOW_FLAGS[*]:-no})"
  nohup emulator -avd "$ANDROID_AVD_NAME" "${WINDOW_FLAGS[@]}" -no-audio -no-boot-anim \
    -no-snapshot-save -gpu swiftshader_indirect > "${TMPDIR:-/tmp}/timeconverter-emulator.log" 2>&1 &
  adb wait-for-device
  for _ in $(seq 1 100); do
    [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 3
  done
  adb shell settings put global window_animation_scale 0 >/dev/null
  adb shell settings put global transition_animation_scale 0 >/dev/null
  adb shell settings put global animator_duration_scale 0 >/dev/null
  echo "booted"
}

boot_emulator_if_needed

echo "building ($INSTALL_TASK)"
# Debug and release share an application id but not a signing key, so one
# cannot install over the other (INSTALL_FAILED_UPDATE_INCOMPATIBLE), and a
# leftover higher versionCode refuses a lower one (INSTALL_FAILED_VERSION_DOWNGRADE).
# On this dev emulator both mean: uninstall and retry. Any other failure (a
# compile error, say) is shown and fatal — never uninstall for those.
INSTALL_LOG="${TMPDIR:-/tmp}/$ANDROID_AVD_NAME-install.log"
if ! (cd "$ANDROID_PROJECT_DIR" && ./gradlew "$INSTALL_TASK" --console=plain -q) >"$INSTALL_LOG" 2>&1; then
  if grep -qE 'INSTALL_FAILED_(UPDATE_INCOMPATIBLE|VERSION_DOWNGRADE)' "$INSTALL_LOG"; then
    echo "installed copy has the other key or a higher versionCode; uninstalling it and retrying"
    adb uninstall "$ANDROID_APP_ID" >/dev/null 2>&1 || true
    (cd "$ANDROID_PROJECT_DIR" && ./gradlew "$INSTALL_TASK" --console=plain -q)
  else
    grep -v '^\s*at ' "$INSTALL_LOG"; echo "install failed (full log: $INSTALL_LOG)"; exit 1
  fi
fi

echo "launching"
adb shell am force-stop "$ANDROID_APP_ID" >/dev/null
# String extras, each single-quoted because `adb shell` re-parses the line.
# favourites / selectedTab / clockOffsetMinutes are read by DEBUG builds only
# (DebugLaunchOptions.kt); a release build ignores them.
LAUNCH_EXTRAS=()
[[ -n "$INITIAL_INPUT" ]] && LAUNCH_EXTRAS+=(--es initialInput "'$INITIAL_INPUT'")
[[ -n "$FAVOURITES" ]] && LAUNCH_EXTRAS+=(--es favourites "'$FAVOURITES'")
[[ -n "$SELECTED_TAB" ]] && LAUNCH_EXTRAS+=(--es selectedTab "'$SELECTED_TAB'")
[[ -n "$CLOCK_OFFSET_MINUTES" ]] && LAUNCH_EXTRAS+=(--es clockOffsetMinutes "'$CLOCK_OFFSET_MINUTES'")
adb shell am start -n "$ANDROID_APP_ID/.MainActivity" ${LAUNCH_EXTRAS[@]+"${LAUNCH_EXTRAS[@]}"} >/dev/null

if [[ -n "$SCREENSHOT" ]]; then
  sleep 2
  adb exec-out screencap -p > "$SCREENSHOT"
  echo "screenshot: $SCREENSHOT"
fi
