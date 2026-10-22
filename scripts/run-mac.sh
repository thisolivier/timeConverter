#!/usr/bin/env bash
# run-mac.sh — build the Mac Catalyst app and launch it on this Mac.
#
# Usage:
#   scripts/run-mac.sh              # Debug, unsandboxed (the normal dev loop)
#   scripts/run-mac.sh --sandboxed  # Debug, but with the App Sandbox on
#
# --sandboxed exists because the shipped Mac build will be sandboxed (the Mac
# App Store requires it) while Debug deliberately is not, and the interesting
# question is whether the menu-bar plug-in still loads under the sandbox. It
# applies the same entitlements file the Release/macOS build uses, keeping the
# rest of the Debug build — ad-hoc signing, no team, no provisioning profile —
# untouched. Everything else about this script, and all of scripts/test.sh,
# stays unsandboxed.
#
# What it cannot tell you: the Release build also gets the hardened runtime,
# whose library validation requires the plug-in and the host to share a Team
# ID. Ad-hoc signing has no team, so an ad-hoc *Release* build fails to load
# the plug-in for that reason alone. Proving the real combination needs the
# macOS distribution profile — see scripts/ship-mac.sh.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConverter"
DERIVED_DATA="$REPO_DIR/build/DerivedData"

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
  # cleanly. It is not a provisioning setting, so passing it project-wide is
  # harmless; it is still confined to this mode so the normal dev loop keeps
  # Xcode's default.
  extra_settings=("ENABLE_DEBUG_DYLIB=NO")
fi

(cd "$REPO_DIR" && xcodegen generate --quiet)

xcodebuild build \
  -project "$REPO_DIR/TimeConverter.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS,variant=Mac Catalyst,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  "MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f1-2)" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  ${extra_settings[@]+"${extra_settings[@]}"} \
  2>&1 | tail -5

APP_PATH="$DERIVED_DATA/Build/Products/Debug-maccatalyst/TimeConverter.app"

if [[ "$SANDBOXED" == "1" ]]; then
  # Re-signing the outer bundle, NOT passing CODE_SIGN_ENTITLEMENTS to
  # xcodebuild. A command-line build setting applies to every target, so it
  # would hand the entitlements file to the Controls extension and — much
  # worse — to TimeConverterMenuBar.bundle, which must carry no entitlements
  # at all (a loadable plug-in inherits the host's; its own are the documented
  # cause of ITMS-90283). `codesign` on the .app alone leaves the nested
  # signatures in Contents/PlugIns exactly as the build made them.
  echo ""
  echo "Re-signing the app bundle with the App Sandbox entitlement..."
  codesign --force --sign - \
    --entitlements "$REPO_DIR/TimeConverter/TimeConverter-macOS.entitlements" \
    "$APP_PATH"
  echo "Sandboxed. Container: ~/Library/Containers/dev.thisolivier.timeconverter"
  echo "Entitlements now on the app:"
  codesign -d --entitlements - --xml "$APP_PATH" 2>/dev/null | plutil -p -

  # Swapping the signature under a bundle path that launchd has already run
  # poisons its cached service record: the first launch dies with
  # "Launchd job spawn failed" / AMFI "Launch Constraint Violation", launchd
  # then discards the record itself, and the next launch succeeds. Re-register
  # with LaunchServices to avoid relying on that, and retry once if it still
  # happens — measured behaviour, not a guess.
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
    -f -R -trusted "$APP_PATH" 2>/dev/null || true
fi

echo "Launching $APP_PATH"
if ! open "$APP_PATH"; then
  echo "First launch refused — retrying once (see the lsregister note above)."
  sleep 1
  open "$APP_PATH"
fi
