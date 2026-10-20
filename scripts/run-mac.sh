#!/usr/bin/env bash
# run-mac.sh — build the Mac Catalyst app and launch it on this Mac.
#
# Usage: scripts/run-mac.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConverter"
DERIVED_DATA="$REPO_DIR/build/DerivedData"

(cd "$REPO_DIR" && xcodegen generate --quiet)

xcodebuild build \
  -project "$REPO_DIR/TimeConverter.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS,variant=Mac Catalyst,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  "MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f1-2)" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  2>&1 | tail -5

APP_PATH="$DERIVED_DATA/Build/Products/Debug-maccatalyst/TimeConverter.app"
echo "Launching $APP_PATH"
open "$APP_PATH"
