#!/usr/bin/env bash
# ship-mac.sh — archive, export and upload the **native macOS** build of
# TimeConverter to the **macOS** platform train of App Store Connect app
# 6825044484 ("Time Converter 3000"). Backlog items 12b + 16.
#
# Sibling of scripts/ship.sh, not a replacement for it. Same app record, same
# bundle id, same build-number source of truth (scripts/lib/version.sh) — a
# different platform train, and since item 16 a genuinely different *target*:
#
#   ship.sh      TimeConverter      iOS archive -> .ipa -> altool -t ios
#                                   Also runs on the Mac through TestFlight's
#                                   "iPhone and iPad app on Mac" compatibility
#                                   runtime. That path still works and is
#                                   untouched by this script.
#   ship-mac.sh  TimeConverterMac   native macOS archive -> .pkg
#                                   -> altool -t macos
#                                   The menu-bar app: MenuBarExtra, ⌃⌥T, no
#                                   Dock icon. Not reachable down the iOS lane
#                                   at all, which is why this lane exists.
#
# What changed from the Catalyst version of this script:
#   - destination is `generic/platform=macOS`, not
#     `generic/platform=macOS,variant=Mac Catalyst`.
#   - one provisioning profile, not two. The Controls extension is iOS-only
#     (no Control Center on the Mac) so there is no Mac profile for it, and the
#     loadable menu-bar bundle it used to assert about no longer exists.
#   - the portal profile TYPE is plain "Mac" / Mac App Store, not
#     "Mac Catalyst".
#   - the Mac Installer Distribution certificate requirement is unchanged: it
#     is a property of the macOS App Store, not of Catalyst.
#
# Usage:
#   scripts/ship-mac.sh <new-build-number>                # bump, archive, export, upload
#   scripts/ship-mac.sh <new-build-number> --skip-upload  # dry run, stop before altool
#   scripts/ship-mac.sh --validate-only                   # NO bump: archive the current
#                                                         # build number and ask Apple's
#                                                         # validator about it without
#                                                         # delivering anything
#   scripts/ship-mac.sh --help
#
# --validate-only costs nothing. `altool --validate-app` runs the same ITMS
# validation as an upload but delivers nothing, so it consumes no build number
# and creates no undeletable row in the build list — which matters doubly on
# macOS, where CFBundleVersion must increase monotonically across *all* version
# trains, so a number burned on a rejected Mac upload is unrecoverable.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_YML="$REPO_DIR/project.yml"
BUILD_DIR="$REPO_DIR/build"
SIGNING_DIR="$HOME/sites/navidromClient/spike/.signing"
KEYCHAIN="$HOME/Library/Keychains/spike-build.keychain-db"
SCHEME="TimeConverterMac"
PRODUCT_NAME="TimeConverter"
BUNDLE_ID="dev.thisolivier.timeconverter"
# Distinct paths from ship.sh's, so an iOS archive and a Mac archive can
# coexist in build/ and neither run can mistake the other's output for its own.
ARCHIVE_PATH="$BUILD_DIR/$PRODUCT_NAME-mac.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-mac"
EXPORT_OPTIONS="$REPO_DIR/ExportOptions-mac.plist"

# Named exactly as ExportOptions-mac.plist and project.yml's
# TimeConverterMac Release PROVISIONING_PROFILE_SPECIFIER expect. Change in one
# place and you must change all three.
APP_PROFILE_NAME="TimeConverter Mac App Store"
INSTALLER_IDENTITY="Mac Installer Distribution"

# Native macOS. No `variant=Mac Catalyst` — that variant no longer exists in
# this project, and asking for it fails outright.
MAC_DESTINATION='generic/platform=macOS'

usage() {
  cat <<USAGE
Usage: $0 <new-build-number> [--skip-upload]
       $0 --validate-only

Archives the native macOS TimeConverter, exports a .pkg for App Store Connect,
and uploads it to the macOS platform train of app 6825044484.

Prerequisites beyond scripts/ship.sh's:
  - A '$APP_PROFILE_NAME' provisioning profile installed.
    This is a **macOS** profile (.provisionprofile), portal type
    "Mac App Store Connect" with profile type **"Mac"** (NOT "Mac Catalyst" —
    that was the retired Catalyst lane). The existing iOS .mobileprovision
    cannot be reused: a profile is platform-scoped, and the iOS one reports
    platforms "visionOS, watchOS, and iOS".
  - A '$INSTALLER_IDENTITY' certificate in $KEYCHAIN.
    This is a different *kind* of certificate from Apple Distribution —
    installer certificates have different OIDs and are not interchangeable —
    and it exists because the macOS App Store product is a signed installer
    package, not an app bundle.

  NONE of the above exists yet. Until it does, this script stops in preflight
  with the portal steps; see docs/testflight-setup-checklist.md "macOS train".

Options:
  --skip-upload    Run preflight, bump, archive and export, then stop before
                   altool. SKIP_UPLOAD=1 has the same effect.
  --validate-only  Do NOT bump the build number. Archive the build number
                   project.yml already carries, export it, and run
                   'altool --validate-app' instead of '--upload-app'. Nothing
                   is delivered and no build number is consumed.
USAGE
  exit "${1:-0}"
}

step() { echo ""; echo "=== $1 ==="; }
fail() { echo "FAILED at step: $1"; exit 1; }

# shellcheck source=lib/version.sh
source "$SCRIPTS_DIR/lib/version.sh"

SKIP_UPLOAD="${SKIP_UPLOAD:-0}"
VALIDATE_ONLY=0
NEW_BUILD_NUMBER=""

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage 0
[[ $# -eq 0 ]] && usage 1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-upload) SKIP_UPLOAD=1 ;;
    --validate-only) VALIDATE_ONLY=1 ;;
    --help|-h) usage 0 ;;
    -*) echo "Error: unknown argument '$1'"; usage 1 ;;
    *)
      if [[ -n "$NEW_BUILD_NUMBER" ]]; then
        echo "Error: unexpected second build number '$1'"; usage 1
      fi
      NEW_BUILD_NUMBER="$1" ;;
  esac
  shift
done

if [[ "$VALIDATE_ONLY" == "1" && -n "$NEW_BUILD_NUMBER" ]]; then
  echo "Error: --validate-only deliberately takes no build number — it archives"
  echo "       whatever project.yml currently carries, precisely so that asking"
  echo "       Apple's validator a question costs nothing."
  usage 1
fi
if [[ "$VALIDATE_ONLY" == "0" && -z "$NEW_BUILD_NUMBER" ]]; then
  echo "Error: a build number is required (or use --validate-only)"
  usage 1
fi
if [[ -n "$NEW_BUILD_NUMBER" ]] && ! [[ "$NEW_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be a positive integer, got '$NEW_BUILD_NUMBER'"
  exit 1
fi

# ------------------------------------------------------------------
step "1/7 Source API key + unlock keychain"

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
security unlock-keychain \
  -p "$(cat "$SIGNING_DIR/keychain.password")" \
  "$KEYCHAIN" 2>/dev/null || true
echo "Keychain unlocked, KEY_ID=$APPSTORE_KEY_ID"

# ------------------------------------------------------------------
step "2/7 Preflight: macOS signing assets"

# Preflight runs BEFORE the version bump on purpose. The portal assets are the
# known-missing piece, and a failed run that has already edited project.yml
# leaves a bumped number behind that the next run's monotonicity guard then
# rejects — a self-inflicted dead end on the one platform where build numbers
# are unrecoverable.
#
# Set SKIP_PREFLIGHT=1 to run the archive anyway. That is the dry-run mode used
# to *discover* what the portal has to produce: the archive fails in signing
# and names the exact profile it wanted. Never use it for a real upload.

# Xcode 16+ nominally keeps profiles in
# ~/Library/Developer/Xcode/UserData/Provisioning Profiles, but the legacy
# MobileDevice path is still where this machine's working iOS profiles live
# (and Apple staff have cited both). Search both; install into both.
PROFILE_DIRS=(
  "$HOME/Library/MobileDevice/Provisioning Profiles"
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
)

# find_profile_by_name <name> -> prints "<path>\t<platforms>" and returns 0
#
# Matched by Name rather than UUID because a regenerated profile keeps its name
# and changes its UUID, and project.yml/ExportOptions-mac.plist both name it.
find_profile_by_name() {
  local wanted="$1" dir candidate decoded name platforms
  for dir in "${PROFILE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for candidate in "$dir"/*.provisionprofile "$dir"/*.mobileprovision; do
      [[ -f "$candidate" ]] || continue
      decoded="$(security cms -D -i "$candidate" 2>/dev/null)" || continue
      name="$(printf '%s' "$decoded" | plutil -extract Name raw -o - - 2>/dev/null)" || continue
      [[ "$name" == "$wanted" ]] || continue
      platforms="$(printf '%s' "$decoded" | plutil -extract Platform json -o - - 2>/dev/null || echo '[]')"
      printf '%s\t%s\n' "$candidate" "$platforms"
      return 0
    done
  done
  return 1
}

PREFLIGHT_PROBLEMS=()

if found="$(find_profile_by_name "$APP_PROFILE_NAME")"; then
  profile_path="${found%%$'\t'*}"
  profile_platforms="${found##*$'\t'}"
  if [[ "$profile_platforms" != *macOS* && "$profile_platforms" != *macosx* ]]; then
    PREFLIGHT_PROBLEMS+=("profile '$APP_PROFILE_NAME' is installed but its platforms are $profile_platforms — no macOS. It is the iOS profile; a macOS one is a separate artifact.")
  else
    echo "OK   profile '$APP_PROFILE_NAME' -> $(basename "$profile_path") $profile_platforms"
  fi
else
  PREFLIGHT_PROBLEMS+=("profile '$APP_PROFILE_NAME' is not installed in either provisioning-profiles directory.")
fi

# `security find-identity -p codesigning` will NEVER list an installer identity
# — it is not a codesigning certificate. Hence the unfiltered query.
if security find-identity -v "$KEYCHAIN" 2>/dev/null | grep -q "3rd Party Mac Developer Installer\|Mac Installer Distribution"; then
  echo "OK   '$INSTALLER_IDENTITY' certificate present"
else
  PREFLIGHT_PROBLEMS+=("no '$INSTALLER_IDENTITY' (a.k.a. '3rd Party Mac Developer Installer') certificate in $KEYCHAIN. The Apple Distribution certificate cannot stand in for it: installer certificates carry different OIDs and are not interchangeable.")
fi

if [[ ${#PREFLIGHT_PROBLEMS[@]} -gt 0 ]]; then
  echo ""
  echo "The macOS train is not set up yet. ${#PREFLIGHT_PROBLEMS[@]} thing(s) missing:"
  for problem in "${PREFLIGHT_PROBLEMS[@]}"; do
    echo "  - $problem"
  done
  cat <<GUIDANCE

Nothing has been changed: no bump, no archive, no upload. This is a portal
errand, and the full version is under "macOS train" in
docs/testflight-setup-checklist.md. In short, at developer.apple.com (team
CNHB9B5GX6):

  1. Certificates -> + -> "Mac Installer Distribution". Upload the existing
     CSR at $SIGNING_DIR/distribution.csr.
     Download the .cer to that same directory and import it into
     $KEYCHAIN.
  2. Identifiers -> dev.thisolivier.timeconverter -> tick "macOS" / "Mac", so a
     macOS profile can be issued against the SAME App ID. The bundle id does
     not change. (Only the app's App ID — the Controls extension is iOS-only
     and needs nothing here.)
  3. Profiles -> + -> Distribution -> "Mac App Store Connect"
     -> Profile Type **"Mac"** -> App ID dev.thisolivier.timeconverter
     -> certificate "Apple Distribution" -> name it exactly
     "$APP_PROFILE_NAME".
  4. Download the .provisionprofile and install it into BOTH
     $(printf '%s' "${PROFILE_DIRS[0]}")/
     and
     $(printf '%s' "${PROFILE_DIRS[1]}")/

Then re-run:  $0 --validate-only
GUIDANCE
  if [[ "${SKIP_PREFLIGHT:-0}" == "1" ]]; then
    echo ""
    echo "SKIP_PREFLIGHT=1 — continuing anyway. The archive is EXPECTED to fail"
    echo "in signing, naming the exact profile it wanted. That text is the point."
  else
    fail "preflight (macOS signing assets missing)"
  fi
fi

# ------------------------------------------------------------------
step "3/7 Build number + regenerate project"

if [[ "$VALIDATE_ONLY" == "1" ]]; then
  NEW_BUILD_NUMBER="$(read_build_number "$PROJECT_YML")"
  if [[ -z "$NEW_BUILD_NUMBER" ]]; then
    fail "version read (could not find CURRENT_PROJECT_VERSION in project.yml)"
  fi
  echo "--validate-only: not bumping. Archiving current CURRENT_PROJECT_VERSION=$NEW_BUILD_NUMBER."
else
  bump_build_number "$PROJECT_YML" "$NEW_BUILD_NUMBER"
  echo "Note: macOS requires CFBundleVersion to increase monotonically across"
  echo "      ALL platform trains, so this number must also exceed anything the"
  echo "      iOS train has used. project.yml is the shared source of truth, so"
  echo "      it does by construction."
fi

( cd "$REPO_DIR" && xcodegen generate ) || fail "xcodegen generate"
echo "xcodegen generate complete — TimeConverter.xcodeproj regenerated from project.yml"

# ------------------------------------------------------------------
step "4/7 Archive (native macOS)"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

# Release signing lives in project.yml's TimeConverterMac configs.Release, now
# unconditional — the `[sdk=macosx*]` conditions the Catalyst lane needed
# existed only because one target served two platforms.
#
# Not passed here: command-line-wide provisioning args leak into every target
# in the build, including the TimeConverterCore package's, which rejects them.
xcodebuild \
  -project "$REPO_DIR/$PRODUCT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$MAC_DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates=NO \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
  archive 2>&1 | tail -20

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  fail "archive (xcarchive not found)"
fi

# A macOS app is a *deep* bundle: Contents/Info.plist, not Info.plist at the
# root the way the iOS lane's flat bundle has it. Same assertion as ship.sh,
# different path — and worth keeping, because the whole point of the $(VAR)
# placeholders in project.yml is that a frozen literal CFBundleVersion once
# survived a bump undetected.
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/$PRODUCT_NAME.app"
ARCHIVE_INFO_PLIST="$ARCHIVED_APP/Contents/Info.plist"
ARCHIVED_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "unreadable")
if [[ "$ARCHIVED_BUILD" != "$NEW_BUILD_NUMBER" ]]; then
  fail "archive (embedded CFBundleVersion is '$ARCHIVED_BUILD', expected '$NEW_BUILD_NUMBER')"
fi

ARCHIVED_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "unreadable")
if [[ "$ARCHIVED_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
  echo "Error: archived CFBundleIdentifier is '$ARCHIVED_BUNDLE_ID', expected '$BUNDLE_ID'."
  echo "       The Mac app shares the iOS app's bundle id on purpose — that is"
  echo "       what makes it the macOS train of app 6825044484 rather than a"
  echo "       second app record."
  fail "archive (unexpected bundle identifier)"
fi
echo "Archive succeeded (CFBundleVersion $ARCHIVED_BUILD, bundle id $ARCHIVED_BUNDLE_ID)"

# ------------------------------------------------------------------
step "5/7 Assert the archive is the shape the Mac App Store wants"

# The Catalyst version of this step policed an embedded loadable .bundle
# (ITMS-90283) and an .appex. The native archive has neither: one executable,
# one profile, one sandbox. What is left is worth keeping because both are
# mechanical ingestion rejections.

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$ARCHIVE_INFO_PLIST" 2>/dev/null)" != "true" ]]; then
  echo "Error: LSUIElement is not set in the archived app. The Mac product is a"
  echo "       menu-bar utility; without this it ships with a Dock icon and no"
  echo "       window, which is the worst of both designs."
  fail "archive (LSUIElement missing)"
fi
echo "OK   LSUIElement — menu-bar utility, no Dock icon"

# macOS uses embedded.provisionprofile, not the iOS embedded.mobileprovision —
# different file name as well as different location, per TN3125.
if [[ ! -f "$ARCHIVED_APP/Contents/embedded.provisionprofile" ]]; then
  echo "Error: no Contents/embedded.provisionprofile in the archived app."
  echo "       A distribution-signed macOS app must embed one."
  fail "signing assertion (no embedded provisioning profile)"
fi
echo "OK   Contents/embedded.provisionprofile present"

if ! codesign -d --entitlements - --xml "$ARCHIVED_APP" 2>/dev/null \
    | plutil -p - 2>/dev/null | grep -q '"com.apple.security.app-sandbox" => true'; then
  echo "Error: the app is not sandboxed. The Mac App Store rejects this at"
  echo "       ingestion (ITMS-90296)."
  fail "signing assertion (app-sandbox missing)"
fi
echo "OK   app is sandboxed"

# ------------------------------------------------------------------
step "6/7 Export (.pkg for App Store Connect)"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates=NO 2>&1 | tail -3

# A macOS App Store export is an installer package. `man 7 altool`: "To upload
# your app binary files (.ipa or .pkg)".
PKG_PATH="$EXPORT_DIR/$PRODUCT_NAME.pkg"
if [[ ! -f "$PKG_PATH" ]]; then
  FOUND_PKG=$(find "$EXPORT_DIR" -maxdepth 1 -name '*.pkg' | head -1)
  if [[ -n "$FOUND_PKG" ]]; then
    PKG_PATH="$FOUND_PKG"
  else
    echo "Error: no .pkg in $EXPORT_DIR. Contents:"
    ls -la "$EXPORT_DIR" 2>/dev/null || echo "  (directory missing)"
    fail "export (pkg not found)"
  fi
fi
echo "Export succeeded: $(basename "$PKG_PATH")"

# ------------------------------------------------------------------
if [[ "$VALIDATE_ONLY" == "1" ]]; then
  step "7/7 Validate with App Store Connect (nothing delivered)"
  # Same ITMS validation as an upload, no delivery, no build number consumed.
  VALIDATE_OUTPUT=$(xcrun altool --validate-app \
    -f "$PKG_PATH" \
    -t macos \
    --apiKey "$APPSTORE_KEY_ID" \
    --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1) || true

  echo "$VALIDATE_OUTPUT"
  echo ""
  if echo "$VALIDATE_OUTPUT" | grep -qi 'No errors validating'; then
    echo "VALIDATION PASSED for build $NEW_BUILD_NUMBER."
    echo ""
    echo "Note what it does NOT answer: validation is ingestion-time only, so it"
    echo "says nothing about App Review policy. It does retire the open question"
    echo "the Catalyst lane carried — there is no loadable bundle in this archive"
    echo "to be unsupported any more."
    echo ""
    echo "Next: scripts/ship-mac.sh $((NEW_BUILD_NUMBER + 1))"
    exit 0
  else
    echo "VALIDATION FAILED — and the error text is the finding. Record it in"
    echo "docs/testflight-setup-checklist.md verbatim. No build number was"
    echo "consumed either way."
    fail "validation"
  fi
fi

step "7/7 Upload to the macOS TestFlight train"

if [[ "$SKIP_UPLOAD" == "1" ]]; then
  echo "SKIP_UPLOAD set — not calling 'xcrun altool --upload-app'."
  echo "Would have run:"
  echo "  xcrun altool --upload-app -f \"$PKG_PATH\" -t macos --apiKey \"\$APPSTORE_KEY_ID\" --apiIssuer \"\$APPSTORE_ISSUER_ID\""
  echo ""
  echo "Consider '$0 --validate-only' instead: it asks Apple the same"
  echo "ingestion questions for real, and still delivers nothing."
  DELIVERY_UUID="(skipped)"
else
  # `|| true` so a nonzero altool exit reaches the grep below rather than being
  # eaten by set -e inside the command substitution, which on the very first
  # TimeConverter upload made Apple's 90023/90474 rejections vanish silently.
  #
  # -t macos: `altool --help` on this Xcode spells the enum
  # "{macos | ios | appletvos | visionos}". The old `osx` value is stale.
  UPLOAD_OUTPUT=$(xcrun altool --upload-app \
    -f "$PKG_PATH" \
    -t macos \
    --apiKey "$APPSTORE_KEY_ID" \
    --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1) || true

  echo "$UPLOAD_OUTPUT"

  if ! echo "$UPLOAD_OUTPUT" | grep -q 'UPLOAD SUCCEEDED'; then
    fail "upload"
  fi

  DELIVERY_UUID=$(echo "$UPLOAD_OUTPUT" | grep 'Delivery UUID:' | sed 's/.*Delivery UUID: //')
fi

# ------------------------------------------------------------------
step "Summary"

COMMIT_SHA=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo ""
echo "Mac ship complete!"
echo "  Platform:      macOS (native)"
echo "  Build number:  $NEW_BUILD_NUMBER"
echo "  Delivery UUID: $DELIVERY_UUID"
echo "  Commit:        $COMMIT_SHA"
echo ""
echo "A Delivery UUID is NOT a delivered build — App Store Connect processing"
echo "is asynchronous and can still land on INVALID or FAILED. Check the real"
echo "processing state before telling anyone the build is up:"
echo "  xcrun altool --build-status --apple-id 6825044484 \\"
echo "    --bundle-version $NEW_BUILD_NUMBER --platform macos \\"
echo "    --apiKey \"\$APPSTORE_KEY_ID\" --apiIssuer \"\$APPSTORE_ISSUER_ID\""
echo "  ~/sites/musicLibrary/iOSnative/scripts/asc-builds.py $BUNDLE_ID"
echo "Expect processingState VALID. PROCESSING = wait; INVALID/FAILED ="
echo "investigate, never blind-retry."
echo ""
echo "Note that asc-builds.py lists builds for the bundle id across trains; the"
echo "macOS build is the one whose lsMinimumSystemVersion is non-null. Until"
echo "the first Mac build lands, app 6825044484 has a MAC_OS platform *version*"
echo "record but no macOS TestFlight train, and the Mac tab in TestFlight will"
echo "stay empty."
