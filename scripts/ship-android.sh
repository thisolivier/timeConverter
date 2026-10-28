#!/usr/bin/env bash
# ship-android.sh — build, verify, smoke-test and publish a signed Android APK
# as a GitHub Release, where Obtainium on the partner's phone picks it up.
# Route and reasoning: docs/android-distribution.md. Partner steps:
# docs/android-install.md.
#
# Usage:
#   scripts/ship-android.sh <build-number> [--dry-run]
#   scripts/ship-android.sh --help
#
# The build number is the one shared with the Apple trains (project.yml
# CURRENT_PROJECT_VERSION, via lib/version.sh). Higher than project.yml: it is
# bumped, like scripts/ship.sh does. Equal: accepted without a bump, because an
# Apple lane may already have shipped that number from the same code. Lower:
# refused. Android needs versionCode to only ever increase per installed app.
#
# Release naming (chosen from Obtainium's GitHub source, lib/app_sources/
# github.dart + lib/services/version_service.dart, checked 2026-10-28):
#   tag    android-<versionName>, e.g. android-0.1.0.17
#   title  Time Converter 3000 <MARKETING_VERSION> (<build>)
# Obtainium takes the TAG as the release's version and compares it with the
# installed app's versionName by shared numeric shape. versionName is
# MARKETING_VERSION.build (app/build.gradle.kts) so the tag carries it whole and
# detection works; a bare `android-17` shares no shape with `0.1.0` and
# Obtainium would silently turn version detection off. The `android-` prefix
# keeps clear of any future Apple tags.
#
# This script:
#   1. Preflight: release key present, gh logged in, tag unused, HEAD pushed
#   2. Bump (or confirm) the build number in project.yml
#   3. scripts/test-android.sh, then the core parity gate (lib/parity-gate.sh):
#      every shared fixture ran and passed on the Kotlin side, nothing
#      @Ignore'd, and the Swift core suite agrees with the fixture file
#   4. assembleRelease; assert versionCode, and that the APK is signed by OUR key
#   5. Emulator smoke: install the release, convert "1500 Kolkata in Sydney",
#      assert 8:30 PM + the zone sub-line on screen (catches R8 breakage)
#   6. Copy to TimeConverterAndroid/dist/ (gitignored) with the smoke screenshot
#   7. gh release create with the APK and generated notes — skipped by --dry-run
#
# Ship commit convention, after a real publish (same shape as the Apple lanes):
#   git commit -m "Android build <N> shipped (<one-line what's new>)" project.yml docs/releases.md
#   git push
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_YML="$REPO_DIR/project.yml"
GITHUB_REPOSITORY="thisolivier/timeConverter"
INSTALL_PAGE_URL="https://github.com/$GITHUB_REPOSITORY/blob/main/docs/android-install.md"
SIGNING_PROPERTIES="$HOME/.config/timeconverter/android-release.properties"
SMOKE_INPUT="1500 Kolkata in Sydney"
SMOKE_EXPECTED_TEXTS=("8:30 PM" "AUSTRALIAN EASTERN TIME (SYDNEY, MELBOURNE)")

step() { echo ""; echo "=== $1 ==="; }
fail() { echo "FAILED at step: $1"; exit 1; }
usage() { sed -n '2,40p' "$0"; exit "${1:-0}"; }

source "$SCRIPTS_DIR/lib/version.sh"
source "$SCRIPTS_DIR/lib/parity-gate.sh"
source "$SCRIPTS_DIR/lib/android-env.sh"

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage 0
[[ $# -eq 0 ]] && usage 1
NEW_BUILD_NUMBER="$1"; shift
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Error: unknown argument '$1'"; usage 1 ;;
  esac
  shift
done
[[ "$NEW_BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Error: build number must be a positive integer"; exit 1; }

MARKETING_VERSION="$(grep -m1 'MARKETING_VERSION:' "$PROJECT_YML" | sed -E 's/.*MARKETING_VERSION: *"?([^"]+)"?.*/\1/')"
VERSION_NAME="$MARKETING_VERSION.$NEW_BUILD_NUMBER"
RELEASE_TAG="android-$VERSION_NAME"
RELEASE_TITLE="Time Converter 3000 $MARKETING_VERSION ($NEW_BUILD_NUMBER)"
DIST_DIR="$ANDROID_PROJECT_DIR/dist"
DIST_APK="$DIST_DIR/TimeConverter-$MARKETING_VERSION-$NEW_BUILD_NUMBER.apk"
DIST_SCREENSHOT="$DIST_DIR/TimeConverter-$MARKETING_VERSION-$NEW_BUILD_NUMBER-smoke.png"
BUILT_APK="$ANDROID_PROJECT_DIR/app/build/outputs/apk/release/app-release.apk"

# ------------------------------------------------------------------
step "1/7 Preflight"
[[ -f "$SIGNING_PROPERTIES" ]] || { echo "No release key. Run scripts/setup-android-signing.sh"; fail "preflight (signing)"; }
[[ -x "$ANDROID_BUILD_TOOLS/apksigner" ]] || fail "preflight (apksigner not found under $ANDROID_BUILD_TOOLS)"
if ! $DRY_RUN; then
  gh auth status >/dev/null 2>&1 || fail "preflight (gh not logged in: gh auth login -h github.com)"
  if gh release view "$RELEASE_TAG" -R "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    fail "preflight (release $RELEASE_TAG already exists)"
  fi
  git -C "$REPO_DIR" fetch -q origin
  git -C "$REPO_DIR" merge-base --is-ancestor HEAD origin/main \
    || fail "preflight (HEAD is not on origin/main; push first so the tag points at the shipped code)"
fi
echo "Will ship $RELEASE_TITLE as tag $RELEASE_TAG$($DRY_RUN && echo ' (dry run)')"

# ------------------------------------------------------------------
step "2/7 Build number"
CURRENT_BUILD_NUMBER="$(read_build_number "$PROJECT_YML")"
if [[ "$NEW_BUILD_NUMBER" -eq "$CURRENT_BUILD_NUMBER" ]]; then
  echo "project.yml already at $CURRENT_BUILD_NUMBER — shipping it as is"
else
  bump_build_number "$PROJECT_YML" "$NEW_BUILD_NUMBER"
fi

# ------------------------------------------------------------------
step "3/7 Tests + core parity gate"
"$SCRIPTS_DIR/test-android.sh" | tail -3 || fail "tests"
parity_gate_kotlin_fixtures || fail "parity gate (Kotlin shared fixtures)"
parity_gate_swift_core || fail "parity gate (Swift core suite / fixture contract)"

# ------------------------------------------------------------------
step "4/7 Release build + signature"
rm -f "$BUILT_APK"
(cd "$ANDROID_PROJECT_DIR" && ./gradlew :app:assembleRelease --console=plain -q) || fail "assembleRelease"
[[ -f "$BUILT_APK" ]] || fail "assembleRelease (no APK at $BUILT_APK)"

BADGING="$("$ANDROID_BUILD_TOOLS/aapt2" dump badging "$BUILT_APK" | head -1)"
echo "$BADGING"
[[ "$BADGING" == *"versionCode='$NEW_BUILD_NUMBER'"* && "$BADGING" == *"versionName='$VERSION_NAME'"* ]] \
  || fail "release build (expected versionCode $NEW_BUILD_NUMBER / versionName $VERSION_NAME)"

SIGNER_OUTPUT="$("$ANDROID_BUILD_TOOLS/apksigner" verify --print-certs "$BUILT_APK")" || fail "apksigner verify (unsigned or invalid)"
echo "$SIGNER_OUTPUT" | grep -E 'DN:|SHA-256'
APK_CERT_SHA256="$(echo "$SIGNER_OUTPUT" | grep -m1 'SHA-256 digest' | awk '{print $NF}')"
property() { grep -m1 "^$1=" "$SIGNING_PROPERTIES" | cut -d= -f2-; }
KEYSTORE_CERT_SHA256="$(keytool -list -v -keystore "$(property storeFile)" -alias "$(property keyAlias)" \
  -storepass "$(property storePassword)" | grep -m1 'SHA256:' | awk '{print $2}' | tr -d ':' | tr 'A-F' 'a-f')"
[[ -n "$APK_CERT_SHA256" && "$APK_CERT_SHA256" == "$KEYSTORE_CERT_SHA256" ]] \
  || fail "signature (APK cert $APK_CERT_SHA256 is not the release key $KEYSTORE_CERT_SHA256)"
echo "Signed by the release key ($KEYSTORE_CERT_SHA256)"

# ------------------------------------------------------------------
step "5/7 Emulator smoke (release build)"
mkdir -p "$DIST_DIR"
"$SCRIPTS_DIR/run-android.sh" --release --input "$SMOKE_INPUT" --screenshot "$DIST_SCREENSHOT" || fail "smoke install"
adb shell uiautomator dump /sdcard/timeconverter-smoke.xml >/dev/null
SCREEN_TEXT="$(adb shell cat /sdcard/timeconverter-smoke.xml)"
for expected_text in "${SMOKE_EXPECTED_TEXTS[@]}"; do
  [[ "$SCREEN_TEXT" == *"text=\"$expected_text\""* ]] || fail "smoke ('$expected_text' not on screen; see $DIST_SCREENSHOT)"
  echo "on screen: $expected_text"
done

# ------------------------------------------------------------------
step "6/7 Stage the APK"
cp "$BUILT_APK" "$DIST_APK"
APK_SHA256="$(shasum -a 256 "$DIST_APK" | awk '{print $1}')"
APK_SIZE="$(du -h "$DIST_APK" | awk '{print $1}')"
echo "$DIST_APK ($APK_SIZE, sha256 $APK_SHA256)"
RELEASE_NOTES="$(cat <<NOTES
Time Converter for Android, version $MARKETING_VERSION, build $NEW_BUILD_NUMBER.

- APK: \`$(basename "$DIST_APK")\` ($APK_SIZE)
- SHA-256: \`$APK_SHA256\`
- Signing certificate SHA-256: \`$KEYSTORE_CERT_SHA256\`
- Built from: \`$(git -C "$REPO_DIR" rev-parse --short HEAD)\`

How to install it, and get updates automatically with Obtainium: [$INSTALL_PAGE_URL]($INSTALL_PAGE_URL)
NOTES
)"

# ------------------------------------------------------------------
step "7/7 Publish"
if $DRY_RUN; then
  echo "--dry-run: not publishing. Would run:"
  echo "  gh release create $RELEASE_TAG $DIST_APK -R $GITHUB_REPOSITORY --title \"$RELEASE_TITLE\" --target $(git -C "$REPO_DIR" rev-parse HEAD) --latest"
  echo ""; echo "$RELEASE_NOTES"
  exit 0
fi
gh release create "$RELEASE_TAG" "$DIST_APK" -R "$GITHUB_REPOSITORY" \
  --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES" \
  --target "$(git -C "$REPO_DIR" rev-parse HEAD)" --latest || fail "gh release create"

echo ""
echo "Shipped $RELEASE_TITLE"
echo "  $(gh release view "$RELEASE_TAG" -R "$GITHUB_REPOSITORY" --json url --jq .url)"
record_release android "$NEW_BUILD_NUMBER" "$MARKETING_VERSION" "$(git -C "$REPO_DIR" rev-parse --short HEAD)" "GitHub release $RELEASE_TAG"
report_lane_drift android "$NEW_BUILD_NUMBER"
echo "Now commit the bump: git commit -m \"Android build $NEW_BUILD_NUMBER shipped (...)\" project.yml docs/releases.md && git push"
