#!/usr/bin/env bash
# ship-android.sh: build, verify, smoke-test and publish a signed APK as a
# GitHub Release, where Obtainium on a phone picks it up. No Google Play.
#
#   scripts/ship-android.sh [<build-number>] [--dry-run]
#
# Build number (version.properties BUILD_NUMBER = versionCode, which Android
# requires to only ever increase): omitted = current + 1. Higher than current:
# written. Equal: shipped as is (retry after a failed publish). Lower: refused.
# --dry-run does everything except publish, then restores version.properties.
#
# Release naming. Obtainium takes the release TAG as the version and compares
# it with the installed versionName by shared numeric shape, so:
#   versionName  VERSION_NAME.BUILD_NUMBER   e.g. 0.1.0.17
#   tag          android-<versionName>       e.g. android-0.1.0.17
# A bare `android-17` shares no shape with `0.1.0` and Obtainium silently
# turns version detection off. The prefix keeps clear of any other tags.
#
# Steps: 1 preflight (key, gh login, tag unused, HEAD pushed), 2 build number,
# 3 tests, 4 assembleRelease + version/signature check, 5 emulator smoke of the
# release build (on-screen text), 6 stage in android/dist/, 7 gh release create.
#
# After a real publish: git commit -m "Android build <N> shipped (...)" version.properties && git push
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"
step() { echo ""; echo "=== $1 ==="; }
fail() { echo "FAILED at step: $1"; exit 1; }
usage() { sed -n '2,24p' "$0"; exit "${1:-0}"; }
source "$ANDROID_SCRIPTS_DIR/lib/android-release.sh"

# What the release smoke launches with and must see on screen. Grow these with
# the app: pick text that only renders if the core logic really ran.
SMOKE_INPUT=""
SMOKE_EXPECTED_TEXTS=("Hello from $ANDROID_APP_NAME")
SHIP_BRANCH="${SHIP_BRANCH:-main}"

REQUESTED_BUILD_NUMBER=""
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --help|-h) usage 0 ;;
    *) [[ "$1" =~ ^[0-9]+$ ]] || { echo "Error: unknown argument '$1'"; usage 1; }; REQUESTED_BUILD_NUMBER="$1" ;;
  esac
  shift
done

CURRENT_BUILD_NUMBER="$(version_property BUILD_NUMBER)"
NEW_BUILD_NUMBER="${REQUESTED_BUILD_NUMBER:-$((CURRENT_BUILD_NUMBER + 1))}"
MARKETING_VERSION="$(version_property VERSION_NAME)"
VERSION_NAME="$MARKETING_VERSION.$NEW_BUILD_NUMBER"
RELEASE_TAG="android-$VERSION_NAME"
RELEASE_TITLE="$ANDROID_APP_NAME $MARKETING_VERSION ($NEW_BUILD_NUMBER)"
DIST_DIR="$ANDROID_PROJECT_DIR/dist"
DIST_APK="$DIST_DIR/$ANDROID_APP_NAME-$VERSION_NAME.apk"
DIST_SCREENSHOT="$DIST_DIR/$ANDROID_APP_NAME-$VERSION_NAME-smoke.png"
BUILT_APK="$ANDROID_PROJECT_DIR/app/build/outputs/apk/release/app-release.apk"

# ------------------------------------------------------------------
step "1/7 Preflight"
[[ -f "$ANDROID_SIGNING_PROPERTIES" ]] || { echo "No release key at $ANDROID_SIGNING_PROPERTIES. Run scripts/setup-android-signing.sh"; fail "preflight (signing)"; }
[[ -x "$ANDROID_BUILD_TOOLS/apksigner" ]] || fail "preflight (apksigner not found under $ANDROID_BUILD_TOOLS)"
git -C "$ANDROID_REPO_DIR" rev-parse HEAD >/dev/null 2>&1 || fail "preflight (no git commit to build from)"
[[ "$NEW_BUILD_NUMBER" -ge "$CURRENT_BUILD_NUMBER" ]] \
  || fail "preflight (build $NEW_BUILD_NUMBER is lower than version.properties' $CURRENT_BUILD_NUMBER)"
if ! $DRY_RUN; then
  gh auth status >/dev/null 2>&1 || fail "preflight (gh not logged in: gh auth login -h github.com)"
  gh release view "$RELEASE_TAG" -R "$GITHUB_REPOSITORY" >/dev/null 2>&1 && fail "preflight (release $RELEASE_TAG already exists)"
  git -C "$ANDROID_REPO_DIR" fetch -q origin
  git -C "$ANDROID_REPO_DIR" merge-base --is-ancestor HEAD "origin/$SHIP_BRANCH" \
    || fail "preflight (HEAD is not on origin/$SHIP_BRANCH; push first so the tag points at the shipped code)"
fi
echo "Will ship $RELEASE_TITLE as tag $RELEASE_TAG to $GITHUB_REPOSITORY$($DRY_RUN && echo ' (dry run)')"

# ------------------------------------------------------------------
step "2/7 Build number"
if $DRY_RUN; then
  ORIGINAL_VERSION_FILE="$(cat "$ANDROID_VERSION_FILE")"
  trap 'printf "%s\n" "$ORIGINAL_VERSION_FILE" > "$ANDROID_VERSION_FILE"; echo "(dry run: version.properties restored)"' EXIT
fi
if [[ "$NEW_BUILD_NUMBER" -eq "$CURRENT_BUILD_NUMBER" ]]; then
  echo "version.properties already at $CURRENT_BUILD_NUMBER; shipping it as is"
else
  write_build_number "$NEW_BUILD_NUMBER"
fi

# ------------------------------------------------------------------
step "3/7 Tests"
if ! "$ANDROID_SCRIPTS_DIR/test-android.sh" | tail -3; then fail "tests"; fi   # pipefail: the test exit wins

# ------------------------------------------------------------------
step "4/7 Release build + signature"
rm -f "$BUILT_APK"
(cd "$ANDROID_PROJECT_DIR" && ./gradlew :app:assembleRelease --console=plain -q) || fail "assembleRelease"
[[ -f "$BUILT_APK" ]] || fail "assembleRelease (no APK at $BUILT_APK)"
verify_release_apk "$BUILT_APK" "$NEW_BUILD_NUMBER" "$VERSION_NAME"

# ------------------------------------------------------------------
step "5/7 Emulator smoke (release build)"
mkdir -p "$DIST_DIR"
release_smoke "$DIST_SCREENSHOT" "$SMOKE_INPUT" "${SMOKE_EXPECTED_TEXTS[@]}"

# ------------------------------------------------------------------
step "6/7 Stage the APK"
cp "$BUILT_APK" "$DIST_APK"
echo "$DIST_APK"
RELEASE_NOTES="$(release_notes "$DIST_APK" "$VERSION_NAME" "$NEW_BUILD_NUMBER")"
HEAD_COMMIT="$(git -C "$ANDROID_REPO_DIR" rev-parse HEAD)"

# ------------------------------------------------------------------
step "7/7 Publish"
if $DRY_RUN; then
  echo "--dry-run: not publishing. Would run:"
  echo "  gh release create $RELEASE_TAG $DIST_APK -R $GITHUB_REPOSITORY --title \"$RELEASE_TITLE\" --target $HEAD_COMMIT --latest"
  echo ""; echo "$RELEASE_NOTES"
  exit 0
fi
gh release create "$RELEASE_TAG" "$DIST_APK" -R "$GITHUB_REPOSITORY" \
  --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES" --target "$HEAD_COMMIT" --latest \
  || fail "gh release create"

echo ""
echo "Shipped $RELEASE_TITLE"
echo "  $(gh release view "$RELEASE_TAG" -R "$GITHUB_REPOSITORY" --json url --jq .url)"
echo "Now commit the bump: git commit -m \"Android build $NEW_BUILD_NUMBER shipped (...)\" version.properties && git push"
