#!/usr/bin/env bash
# ship.sh — archive, export, and upload TimeConverter to TestFlight.
#
# Adapted from musicLibrary/iOSnative/scripts/ship-naviadmin.sh, the shared
# template for xcodegen-managed projects: project.yml is the source of truth
# and TimeConverter.xcodeproj is gitignored, regenerated fresh before every
# build.
#
# This lane is iOS only, and it is unchanged by the native restructure (backlog
# item 16). An iOS TestFlight build does also install and run via TestFlight on
# the Mac (user-verified, builds 3 and 4) — but as the *iOS* binary in the
# compatibility runtime, which is a different product from the native menu-bar
# app: no status item, no ⌃⌥T, a window. The Mac experience ships through
# scripts/ship-mac.sh and the TimeConverterMac target. Nothing about that lane
# touches this one.
#
# Usage:
#   scripts/ship.sh <new-build-number> [--skip-upload]
#   scripts/ship.sh --help
#
# Example:
#   scripts/ship.sh 2
#
# This script:
#   1. Sources api-key.env and unlocks the build keychain
#   2. Bumps CURRENT_PROJECT_VERSION in project.yml and regenerates
#      TimeConverter.xcodeproj via `xcodegen generate`
#   3. Archives (xcodebuild archive, Release config, generic iOS destination)
#      and asserts the archive really embeds the bumped build number
#   4. Exports to .ipa (xcodebuild -exportArchive, ExportOptions.plist)
#   5. Uploads to TestFlight (xcrun altool --upload-app)
#      — pass --skip-upload (or set SKIP_UPLOAD=1) to stop before this step,
#        e.g. for dry-run verification of steps 1-4 without a real upload.
#   6. Prints a summary with build number, delivery UUID, and HEAD commit SHA

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_YML="$REPO_DIR/project.yml"
BUILD_DIR="$REPO_DIR/build"
SIGNING_DIR="$HOME/sites/navidromClient/spike/.signing"
KEYCHAIN="$HOME/Library/Keychains/spike-build.keychain-db"
SCHEME="TimeConverter"
PRODUCT_NAME="TimeConverter"
BUNDLE_ID="dev.thisolivier.timeconverter"
ARCHIVE_PATH="$BUILD_DIR/$PRODUCT_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
IPA_PATH="$EXPORT_DIR/$PRODUCT_NAME.ipa"

usage() {
  echo "Usage: $0 <new-build-number> [--skip-upload]"
  echo ""
  echo "Bumps CURRENT_PROJECT_VERSION, archives TimeConverter, exports .ipa,"
  echo "and uploads to TestFlight via altool."
  echo ""
  echo "Prerequisites:"
  echo "  - Xcode installed with iOS SDK, xcodegen installed"
  echo "  - $SIGNING_DIR populated (api-key.env, keychain.password)"
  echo "  - Build keychain created at $KEYCHAIN"
  echo "  - 'TimeConverter App Store' profile installed in"
  echo "    ~/Library/MobileDevice/Provisioning Profiles/"
  echo "  - 'TimeConverter Controls App Store' profile, likewise, for the"
  echo "    embedded Control Center extension (bundle id"
  echo "    dev.thisolivier.timeconverter.controls). It does NOT exist yet:"
  echo "    until it is created, step 3 (archive) fails signing the extension."
  echo "    Portal steps are in the README's shipping note."
  echo ""
  echo "  --skip-upload   Run steps 1-4 (and print what step 5 would do) but"
  echo "                  do not call 'xcrun altool --upload-app'. Useful for"
  echo "                  verifying signing/archive/export without a real"
  echo "                  upload. SKIP_UPLOAD=1 has the same effect."
  echo ""
  echo "Example: $0 2"
  exit "${1:-0}"
}

step() { echo ""; echo "=== $1 ==="; }
fail() { echo "FAILED at step: $1"; exit 1; }

# The build-number read/bump/monotonicity logic lives in lib/version.sh because
# scripts/ship-mac.sh (the native macOS lane) uploads into a second platform
# train of the same App Store Connect record and must agree with
# this script on CFBundleVersion to the digit. Sourced rather than duplicated:
# two copies of a sed one-liner is how the two trains would quietly drift apart.
# `fail` above is the lib's error path, so it must be defined before this.
# shellcheck source=lib/version.sh
source "$SCRIPTS_DIR/lib/version.sh"

SKIP_UPLOAD="${SKIP_UPLOAD:-0}"

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage 0
[[ $# -eq 0 ]] && usage 1

NEW_BUILD_NUMBER="$1"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-upload) SKIP_UPLOAD=1 ;;
    *) echo "Error: unknown argument '$1'"; usage 1 ;;
  esac
  shift
done

if ! [[ "$NEW_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be a positive integer, got '$NEW_BUILD_NUMBER'"
  exit 1
fi

# ------------------------------------------------------------------
step "1/6 Source API key + unlock keychain"

if [[ ! -f "$SIGNING_DIR/api-key.env" ]]; then
  echo "Error: $SIGNING_DIR/api-key.env not found"
  exit 1
fi
# shellcheck disable=SC1091
source "$SIGNING_DIR/api-key.env"

if [[ ! -f "$SIGNING_DIR/keychain.password" ]]; then
  echo "Error: $SIGNING_DIR/keychain.password not found"
  exit 1
fi
# The build keychain auto-locks after 6h; unlocking an already-unlocked
# keychain is harmless, hence the tolerated non-zero exit.
security unlock-keychain \
  -p "$(cat "$SIGNING_DIR/keychain.password")" \
  "$KEYCHAIN" 2>/dev/null || true
echo "Keychain unlocked, KEY_ID=$APPSTORE_KEY_ID"

# ------------------------------------------------------------------
step "2/6 Bump build number + regenerate project"

# project.yml is patched (not the generated pbxproj): patching the pbxproj
# would be silently wiped by the next `xcodegen generate`. Existence check,
# monotonicity guard (ITMS-90189) and read-back verification all live in
# lib/version.sh — see the sourcing note above.
bump_build_number "$PROJECT_YML" "$NEW_BUILD_NUMBER"

( cd "$REPO_DIR" && xcodegen generate ) || fail "xcodegen generate"
echo "xcodegen generate complete — TimeConverter.xcodeproj regenerated from project.yml"

# ------------------------------------------------------------------
step "3/6 Archive"

mkdir -p "$BUILD_DIR"
# A stale archive from a previous run would pass the existence check below and
# silently ship an old binary if this run's archive step failed part-way.
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

# Release signing (Manual + Apple Distribution + the App Store profile) lives
# in project.yml's configs.Release, scoped to the app target — not passed here,
# because command-line-wide provisioning args leak into dependency targets.
# -allowProvisioningUpdates=NO: a hard failure beats a silent portal round-trip
# that quietly mints or re-picks a profile.
xcodebuild \
  -project "$REPO_DIR/$PRODUCT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates=NO \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
  archive 2>&1 | tail -5

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  fail "archive (xcarchive not found)"
fi

# Belt and braces: assert the archive really contains the build we asked for.
# Info.plist is generated by xcodegen from project.yml, and the sibling
# projects have form here — a frozen literal CFBundleVersion once survived a
# bump undetected (see project.yml's note on the $(VAR) placeholders).
ARCHIVE_INFO_PLIST="$ARCHIVE_PATH/Products/Applications/$PRODUCT_NAME.app/Info.plist"
ARCHIVED_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "unreadable")
if [[ "$ARCHIVED_BUILD" != "$NEW_BUILD_NUMBER" ]]; then
  fail "archive (embedded CFBundleVersion is '$ARCHIVED_BUILD', expected '$NEW_BUILD_NUMBER')"
fi
echo "Archive succeeded (CFBundleVersion $ARCHIVED_BUILD)"

# ------------------------------------------------------------------
step "4/6 Export"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$REPO_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates=NO 2>&1 | tail -3

if [[ ! -f "$IPA_PATH" ]]; then
  fail "export (ipa not found at $IPA_PATH)"
fi
echo "Export succeeded"

# ------------------------------------------------------------------
step "5/6 Upload to TestFlight"

if [[ "$SKIP_UPLOAD" == "1" ]]; then
  echo "SKIP_UPLOAD set — not calling 'xcrun altool --upload-app'."
  echo "Would have run:"
  echo "  xcrun altool --upload-app -f \"$IPA_PATH\" -t ios --apiKey \"\$APPSTORE_KEY_ID\" --apiIssuer \"\$APPSTORE_ISSUER_ID\""
  DELIVERY_UUID="(skipped)"
else
  # `|| true` so a nonzero altool exit reaches the grep check below instead of
  # silently killing the script inside the command substitution (set -e would
  # abort the assignment itself, eating altool's error output entirely —
  # observed on the first TimeConverter upload, where Apple's 90023/90474
  # validation rejections vanished without a trace).
  UPLOAD_OUTPUT=$(xcrun altool --upload-app \
    -f "$IPA_PATH" \
    -t ios \
    --apiKey "$APPSTORE_KEY_ID" \
    --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1) || true

  echo "$UPLOAD_OUTPUT"

  if ! echo "$UPLOAD_OUTPUT" | grep -q 'UPLOAD SUCCEEDED'; then
    fail "upload"
  fi

  DELIVERY_UUID=$(echo "$UPLOAD_OUTPUT" | grep 'Delivery UUID:' | sed 's/.*Delivery UUID: //')
fi

# ------------------------------------------------------------------
step "6/6 Summary"

COMMIT_SHA=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo ""
echo "Ship complete!"
echo "  Build number:  $NEW_BUILD_NUMBER"
echo "  Delivery UUID: $DELIVERY_UUID"
echo "  Commit:        $COMMIT_SHA"
echo ""
echo "A Delivery UUID is NOT a delivered build — App Store Connect processing"
echo "is asynchronous and can still land on INVALID or FAILED. Check the real"
echo "processing state before telling anyone the build is up:"
echo "  ~/sites/musicLibrary/iOSnative/scripts/asc-builds.py $BUNDLE_ID"
echo "Expect processingState VALID. PROCESSING = wait; INVALID/FAILED ="
echo "investigate, never blind-retry."
