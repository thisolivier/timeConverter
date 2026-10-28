#!/usr/bin/env bash
# run-android.sh — build, install and launch the app on the emulator.
#
# Headless by default, because this machine is driven over ssh: the emulator
# runs with no window and you look at it through screenshots. Pass --window on
# a machine with a display.
#
#   scripts/run-android.sh                        # boot if needed, build, install, launch
#   scripts/run-android.sh --input "12pm ET in London"   # launch with the field prefilled (debug builds)
#   scripts/run-android.sh --screenshot out.png   # ...then capture the screen to a PNG
#   scripts/run-android.sh --window               # emulator with a window
#   scripts/run-android.sh --stop                 # shut the emulator down
#
# First run of an emulator may trigger a macOS firewall/network prompt on the
# machine's screen — accept it once.
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"

INITIAL_INPUT=""
SCREENSHOT=""
WINDOW_FLAGS=(-no-window)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INITIAL_INPUT="$2"; shift 2 ;;
    --screenshot) SCREENSHOT="$2"; shift 2 ;;
    --window) WINDOW_FLAGS=(); shift ;;
    --stop) adb emu kill >/dev/null 2>&1 || true; echo "emulator stopped"; exit 0 ;;
    --help|-h) sed -n '2,14p' "$0"; exit 0 ;;
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

echo "building"
(cd "$ANDROID_PROJECT_DIR" && ./gradlew :app:installDebug --console=plain -q)

echo "launching"
adb shell am force-stop "$ANDROID_APP_ID" >/dev/null
if [[ -n "$INITIAL_INPUT" ]]; then
  adb shell am start -n "$ANDROID_APP_ID/.MainActivity" --es initialInput "'$INITIAL_INPUT'" >/dev/null
else
  adb shell am start -n "$ANDROID_APP_ID/.MainActivity" >/dev/null
fi

if [[ -n "$SCREENSHOT" ]]; then
  sleep 2
  adb exec-out screencap -p > "$SCREENSHOT"
  echo "screenshot: $SCREENSHOT"
fi
