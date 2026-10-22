#!/usr/bin/env bash
# run-mac.sh — build the **native** macOS menu-bar app and launch it.
#
# Usage:
#   scripts/run-mac.sh              # Debug, unsandboxed (the normal dev loop)
#   scripts/run-mac.sh --sandboxed  # Debug, but with the App Sandbox on
#
# What you should see: no Dock icon, no window, a clock glyph in the menu bar.
# Click it for the converter dropdown; press ⌃⌥T from anywhere for the summoned
# panel. The script tails the app's own log afterwards so the menu-bar item and
# the hotkey registration are visible rather than assumed — "hotkey never
# arrived" and "summon failed" are different bugs and this is how they are told
# apart.
#
# --sandboxed exists because the shipped Mac build will be sandboxed (the Mac
# App Store requires it) while Debug deliberately is not. It applies the same
# entitlements file the Release build uses and keeps the rest of the Debug
# build — ad-hoc signing, no team, no provisioning profile — untouched.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConverterMac"
DERIVED_DATA="$REPO_DIR/build/DerivedData"
# A native macOS Debug build lands in Debug/, not Debug-maccatalyst/.
APP_PATH="$DERIVED_DATA/Build/Products/Debug/TimeConverter.app"
LOG_PREDICATE='subsystem == "dev.thisolivier.timeconverter" AND category == "menubar"'

SANDBOXED=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sandboxed) SANDBOXED=1 ;;
    --help|-h) echo "Usage: $0 [--sandboxed]"; exit 0 ;;
    *) echo "Error: unknown argument '$1'"; echo "Usage: $0 [--sandboxed]"; exit 1 ;;
  esac
  shift
done

extra_settings=()
if [[ "$SANDBOXED" == "1" ]]; then
  # A Debug build normally splits the app into a stub executable plus
  # Contents/MacOS/TimeConverter.debug.dylib. Re-signing such a bundle and then
  # launching it sandboxed dies in AMFI with "Launch Constraint Violation
  # (enforcing)" before any of our code runs — measured, not theorised. Turning
  # the split off gives an ordinary single-binary app that re-signs and launches
  # cleanly.
  extra_settings=("ENABLE_DEBUG_DYLIB=NO")
fi

(cd "$REPO_DIR" && xcodegen generate --quiet)

xcodebuild build \
  -project "$REPO_DIR/TimeConverter.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  "MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f1-2)" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  ${extra_settings[@]+"${extra_settings[@]}"} \
  2>&1 | tail -5

if [[ "$SANDBOXED" == "1" ]]; then
  # Re-signing the outer bundle rather than passing CODE_SIGN_ENTITLEMENTS to
  # xcodebuild: a command-line build setting applies to every target in the
  # build, including the SPM package's, which reject it.
  echo ""
  echo "Re-signing the app bundle with the App Sandbox entitlement..."
  codesign --force --sign - \
    --entitlements "$REPO_DIR/TimeConverterMac/TimeConverter-macOS.entitlements" \
    "$APP_PATH"
  echo "Sandboxed. Container: ~/Library/Containers/dev.thisolivier.timeconverter"
  codesign -d --entitlements - --xml "$APP_PATH" 2>/dev/null | plutil -p -

  # Swapping the signature under a bundle path that launchd has already run
  # poisons its cached service record: the first launch dies with
  # "Launchd job spawn failed" / AMFI "Launch Constraint Violation", launchd
  # then discards the record itself, and the next launch succeeds. Re-register
  # with LaunchServices to avoid relying on that — measured behaviour.
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
    -f -R -trusted "$APP_PATH" 2>/dev/null || true
fi

LAUNCHED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Launching $APP_PATH"
if ! open "$APP_PATH"; then
  echo "First launch refused — retrying once (see the lsregister note above)."
  sleep 1
  open "$APP_PATH"
fi

# The app logs one line naming what actually came up — "status item + ⌃⌥T" on
# the happy path, "no status item" or "no hotkey (…)" when a half of it failed.
# It is emitted a beat after launch, because the MenuBarExtra scene creates its
# status item after applicationDidFinishLaunching.
echo "Waiting for the menu-bar log line..."
for _ in $(seq 1 20); do
  MENUBAR_LOG="$(/usr/bin/log show --predicate "$LOG_PREDICATE" \
    --start "$LAUNCHED_AT" --style compact 2>/dev/null | grep "menu bar ready" || true)"
  [[ -n "$MENUBAR_LOG" ]] && break
  sleep 0.5
done

echo ""
if [[ -n "${MENUBAR_LOG:-}" ]]; then
  echo "$MENUBAR_LOG"
else
  echo "No 'menu bar ready' line in the log yet — the app may still be starting."
  echo "Check by hand:"
  echo "  log show --predicate '$LOG_PREDICATE' --last 2m --style compact"
fi
echo ""
echo "Now: click the clock glyph in the menu bar, then press ⌃⌥T from another"
echo "app. Each press logs a 'hotkey received' line, so a press that never"
echo "arrives is distinguishable from a summon that failed."
