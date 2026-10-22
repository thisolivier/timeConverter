#!/usr/bin/env bash
# ship-mac.sh — archive, export and upload the **Mac Catalyst** build of
# TimeConverter to the **macOS** platform train of App Store Connect app
# 6825044484 ("Time Converter 3000"). Backlog item 12b.
#
# Sibling of scripts/ship.sh, not a replacement for it. Same app record, same
# bundle ids, same build-number source of truth (scripts/lib/version.sh) — a
# different platform train. The two lanes deliver genuinely different binaries:
#
#   ship.sh      iOS archive      -> .ipa -> altool -t ios
#                Runs on the Mac through TestFlight's "iPhone and iPad app on
#                Mac" compatibility runtime, i.e. the *iOS* binary in the iOS
#                runtime. A macOS-SDK AppKit bundle can never load there, which
#                is why 12a's menu bar cannot reach users down this lane.
#   ship-mac.sh  Mac Catalyst     -> .pkg -> altool -t macos
#                archive                The real Catalyst product: Contents/
#                                       MacOS, Contents/PlugIns, the menu-bar
#                                       bundle and the Controls extension.
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
# --validate-only is the point of this script existing before the portal work
# is done. `altool --validate-app` runs the same ITMS validation as an upload
# but delivers nothing, so it costs no build number and creates no undeletable
# row in the build list — which matters doubly on macOS, where CFBundleVersion
# must increase monotonically across *all* version trains, so a number burned
# on a rejected Mac upload is unrecoverable. It is how we get an answer to the
# one question nobody on the public record has answered: whether Apple's
# validator accepts a Catalyst app with a loadable macOS-SDK bundle embedded in
# Contents/PlugIns (docs/menu-bar-poc-plan.md §3).

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
# Distinct paths from ship.sh's, so an iOS archive and a Mac archive can
# coexist in build/ and neither run can mistake the other's output for its own.
ARCHIVE_PATH="$BUILD_DIR/$PRODUCT_NAME-mac.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-mac"
EXPORT_OPTIONS="$REPO_DIR/ExportOptions-mac.plist"

# Named exactly as ExportOptions-mac.plist and project.yml's
# PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*] entries expect. Change in one
# place and you must change all three.
APP_PROFILE_NAME="TimeConverter Mac App Store"
CONTROLS_PROFILE_NAME="TimeConverter Controls Mac App Store"
INSTALLER_IDENTITY="Mac Installer Distribution"

# Mac Catalyst, not native macOS: plain `generic/platform=macOS` would build a
# native AppKit variant this project does not have.
MAC_DESTINATION='generic/platform=macOS,variant=Mac Catalyst'

usage() {
  cat <<USAGE
Usage: $0 <new-build-number> [--skip-upload]
       $0 --validate-only

Archives TimeConverter for Mac Catalyst, exports a .pkg for App Store Connect,
and uploads it to the macOS platform train of app 6825044484.

Prerequisites beyond scripts/ship.sh's:
  - '$APP_PROFILE_NAME' and '$CONTROLS_PROFILE_NAME'
    provisioning profiles installed. These are **macOS** profiles
    (.provisionprofile) of portal type "Mac App Store Connect" / profile type
    "Mac Catalyst". The existing iOS .mobileprovision profiles cannot be
    reused: a profile is platform-scoped, and theirs report platforms
    "visionOS, watchOS, and iOS".
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

for profile_name in "$APP_PROFILE_NAME" "$CONTROLS_PROFILE_NAME"; do
  if found="$(find_profile_by_name "$profile_name")"; then
    profile_path="${found%%$'\t'*}"
    profile_platforms="${found##*$'\t'}"
    if [[ "$profile_platforms" != *macOS* && "$profile_platforms" != *macosx* ]]; then
      PREFLIGHT_PROBLEMS+=("profile '$profile_name' is installed but its platforms are $profile_platforms — no macOS. It is the iOS profile; a macOS one is a separate artifact.")
    else
      echo "OK   profile '$profile_name' -> $(basename "$profile_path") $profile_platforms"
    fi
  else
    PREFLIGHT_PROBLEMS+=("profile '$profile_name' is not installed in either provisioning-profiles directory.")
  fi
done

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
errand, and the full two-minute version is under "macOS train" in
docs/testflight-setup-checklist.md. In short, at developer.apple.com (team
CNHB9B5GX6):

  1. Certificates -> + -> "Mac Installer Distribution". Upload the existing
     CSR at $SIGNING_DIR/distribution.csr.
     Download the .cer to that same directory.
  2. Identifiers -> dev.thisolivier.timeconverter -> tick "Mac Catalyst"
     (and the same for dev.thisolivier.timeconverter.controls), so a macOS
     profile can be issued against the SAME App ID — the bundle ids do not
     change and must not gain a 'maccatalyst.' prefix.
  3. Profiles -> + -> Distribution -> "Mac App Store Connect"
     -> Profile Type "Mac Catalyst" -> App ID dev.thisolivier.timeconverter
     -> certificate "Apple Distribution" -> name it exactly
     "$APP_PROFILE_NAME".
  4. Repeat 3 for dev.thisolivier.timeconverter.controls, named exactly
     "$CONTROLS_PROFILE_NAME".
  5. Download both .provisionprofile files and install each into BOTH
     $(printf '%s' "${PROFILE_DIRS[0]}")/
     and
     $(printf '%s' "${PROFILE_DIRS[1]}")/

Then re-run:  $0 --validate-only
GUIDANCE
  fail "preflight (macOS signing assets missing)"
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
step "4/7 Archive (Mac Catalyst)"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

# Release signing for the macOS SDK lives in project.yml's configs.Release
# behind [sdk=macosx*] conditions, scoped to the app and extension targets.
# Not passed here: command-line-wide provisioning args leak into every target,
# including the menu-bar bundle, which must carry no profile at all.
xcodebuild \
  -project "$REPO_DIR/$PRODUCT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$MAC_DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates=NO \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
  archive 2>&1 | tail -5

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

# The bundle id must NOT have acquired a 'maccatalyst.' prefix. If it does,
# App Store Connect will not attach the build to app 6825044484 and the error
# arrives late and unhelpfully.
ARCHIVED_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "unreadable")
if [[ "$ARCHIVED_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
  echo "Error: archived CFBundleIdentifier is '$ARCHIVED_BUNDLE_ID', expected '$BUNDLE_ID'."
  echo "       A 'maccatalyst.' prefix means DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER"
  echo "       has been turned on; this app shares one bundle id across platforms."
  fail "archive (unexpected bundle identifier)"
fi
echo "Archive succeeded (CFBundleVersion $ARCHIVED_BUILD, bundle id $ARCHIVED_BUNDLE_ID)"

# ------------------------------------------------------------------
step "5/7 Assert the embedded bundle is signed the only way it can be"

# This is the ITMS-90283 trip-wire, checked locally instead of discovered at
# ingestion. Apple's position (Creating Distribution-Signed Code for Mac;
# "Notarizing macOS software before distribution"): entitlements only make
# sense on a main executable, and "plug-ins don't declare their own
# entitlements — they inherit the entitlements of the host process". Every
# public ITMS-90283 report naming an embedded .bundle names a *provisioning
# profile found inside that bundle*. So: the app and the extension each get
# exactly one profile and the sandbox entitlement; the plug-in gets neither.
MENUBAR_BUNDLE="$ARCHIVED_APP/Contents/PlugIns/${PRODUCT_NAME}MenuBar.bundle"
CONTROLS_APPEX="$ARCHIVED_APP/Contents/PlugIns/${PRODUCT_NAME}Controls.appex"

if [[ ! -d "$MENUBAR_BUNDLE" ]]; then
  echo "Error: the Catalyst archive has no $(basename "$MENUBAR_BUNDLE")."
  echo "       That is the entire reason this lane exists (backlog item 12a) —"
  echo "       check project.yml's platformFilter/embed/copy dependency block."
  fail "archive (menu-bar bundle missing from Contents/PlugIns)"
fi
if [[ ! -d "$CONTROLS_APPEX" ]]; then
  fail "archive (Controls extension missing from Contents/PlugIns)"
fi

# `codesign -d --entitlements -` prints nothing at all for an unentitled
# binary. Even an EMPTY entitlements dict on a non-main-executable is the bug.
MENUBAR_ENTITLEMENTS=$(codesign -d --entitlements - --xml "$MENUBAR_BUNDLE" 2>/dev/null || true)
if [[ -n "$MENUBAR_ENTITLEMENTS" ]]; then
  echo "Error: $(basename "$MENUBAR_BUNDLE") carries entitlements:"
  echo "$MENUBAR_ENTITLEMENTS" | plutil -p - || true
  echo "       A loadable plug-in must carry none — it inherits the host's."
  fail "signing assertion (entitlements on a loadable bundle)"
fi
echo "OK   $(basename "$MENUBAR_BUNDLE") has no entitlements"

EMBEDDED_PROFILES=$(find "$ARCHIVED_APP" -name 'embedded.provisionprofile' | sort)
# macOS uses embedded.provisionprofile, not the iOS embedded.mobileprovision —
# different file name as well as different location, per TN3125. If neither is
# present the archive was signed without a profile at all, and export would
# fail later with something far less legible.
if [[ -z "$EMBEDDED_PROFILES" ]]; then
  echo "Error: no embedded.provisionprofile anywhere in the archived app."
  echo "       A distribution-signed macOS app must embed one at"
  echo "       Contents/embedded.provisionprofile (and one per .appex)."
  fail "signing assertion (no embedded provisioning profile)"
fi
UNEXPECTED_PROFILES=$(printf '%s\n' "$EMBEDDED_PROFILES" | grep -F '.bundle/' || true)
if [[ -n "$UNEXPECTED_PROFILES" ]]; then
  echo "Error: a provisioning profile is embedded inside a loadable bundle:"
  printf '%s\n' "$UNEXPECTED_PROFILES"
  echo "       This is the documented cause of ITMS-90283 'Invalid"
  echo "       com.apple.application-identifier entitlement value'."
  fail "signing assertion (profile inside a loadable bundle)"
fi
echo "OK   embedded.provisionprofile only where it belongs:"
printf '%s\n' "$EMBEDDED_PROFILES" | sed "s|$ARCHIVED_APP|     .|"

for sandboxed in "$ARCHIVED_APP" "$CONTROLS_APPEX"; do
  if ! codesign -d --entitlements - --xml "$sandboxed" 2>/dev/null \
      | plutil -p - 2>/dev/null | grep -q '"com.apple.security.app-sandbox" => true'; then
    echo "Error: $(basename "$sandboxed") is not sandboxed. The Mac App Store"
    echo "       rejects this at ingestion (ITMS-90296)."
    fail "signing assertion (app-sandbox missing)"
  fi
done
echo "OK   app and Controls extension are both sandboxed"

# ------------------------------------------------------------------
step "6/7 Export (.pkg for App Store Connect)"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates=NO 2>&1 | tail -3

# A macOS App Store export is an installer package. `man 7 altool`: "To upload
# your app binary files (.ipa or .pkg)". Xcode Help, "Archive export files":
# "for macOS apps, this is an installer package (with a .pkg file extension)".
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
    echo "This is the answer to the open question in docs/menu-bar-poc-plan.md §3:"
    echo "Apple's validator accepts a Catalyst app with the loadable macOS-SDK"
    echo "bundle embedded in Contents/PlugIns. Note what it does NOT answer —"
    echo "validation is ingestion-time only, so it says nothing about App Review"
    echo "policy, and DTS still calls the architecture unsupported."
    echo ""
    echo "Next: scripts/ship-mac.sh $((NEW_BUILD_NUMBER + 1))"
    exit 0
  else
    echo "VALIDATION FAILED — and the error text is the finding. Record it in"
    echo "docs/menu-bar-poc-plan.md §3 verbatim. If it is ITMS-90283 naming"
    echo "TimeConverterMenuBar.bundle, the bundle-in-Catalyst architecture is"
    echo "answered negatively and item 12b needs the LoginItems helper-app"
    echo "route instead. No build number was consumed either way."
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
  # -t macos: `altool --help` on this Xcode (26.40.1) spells the enum
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
echo "  Platform:      macOS (Mac Catalyst)"
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
