#!/usr/bin/env bash
# run-ios.sh — build the app, install it on a booted iOS simulator, and launch.
# Boots the default simulator if none is running.
#
# Usage: scripts/run-ios.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConvertor"
BUNDLE_ID="dev.thisolivier.timeconvertor"
DEFAULT_SIMULATOR="iPhone 17"
DERIVED_DATA="$REPO_DIR/build/DerivedData"

(cd "$REPO_DIR" && xcodegen generate --quiet)

# Prefer an already-booted simulator; otherwise boot the default one.
# Booted-by-UDID destinations are more reliable than name= (which can be
# ambiguous across runtimes).
BOOTED_UDID=$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)
if [[ -z "$BOOTED_UDID" ]]; then
  echo "No booted simulator — booting $DEFAULT_SIMULATOR"
  BOOTED_UDID=$(xcrun simctl list devices available | grep "$DEFAULT_SIMULATOR (" | grep -Eo '[0-9A-F-]{36}' | head -1)
  xcrun simctl boot "$BOOTED_UDID"
  open -a Simulator
fi

xcodebuild build \
  -project "$REPO_DIR/TimeConvertor.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$BOOTED_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  2>&1 | tail -5

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/TimeConvertor.app"
xcrun simctl install "$BOOTED_UDID" "$APP_PATH"
open -a Simulator
xcrun simctl launch "$BOOTED_UDID" "$BUNDLE_ID"
