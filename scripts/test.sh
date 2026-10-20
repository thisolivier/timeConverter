#!/usr/bin/env bash
# test.sh — run TimeConverter's xcodebuild tests.
#
# Adapted from musicLibrary/iOSnative/scripts/test.sh. By default tests run on
# the iOS simulator. The Mac (Catalyst) lane exists because in the sibling
# projects the Mac build shipped broken while the iPhone lane was green — same
# code, different platform behavior (sandbox entitlements, fresh-install
# state). Run --platform all before shipping anything that touches startup
# wiring or storage.
#
# Usage:
#   scripts/test.sh                         # iOS sim, all tests
#   scripts/test.sh SomeTestClass           # iOS sim, one class
#   scripts/test.sh --platform mac          # Mac Catalyst, all
#   scripts/test.sh --platform all          # both platforms
#   scripts/test.sh --help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConverter"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17"
MAC_DESTINATION="platform=macOS,variant=Mac Catalyst,arch=arm64"

usage() {
  echo "Usage: $0 [--platform ios|mac|all] [TestClassName]"
  exit "${1:-0}"
}

PLATFORM="ios"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage 0 ;;
    --platform)
      PLATFORM="${2:-}"
      [[ "$PLATFORM" =~ ^(ios|mac|all)$ ]] || { echo "Error: --platform must be ios, mac, or all"; usage 1; }
      shift 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

ONLY_TESTING=""
if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
  ONLY_TESTING="-only-testing:TimeConverterTests/${POSITIONAL[0]}"
fi

# The .xcodeproj is not tracked in git — regenerate it from project.yml.
(cd "$REPO_DIR" && xcodegen generate --quiet)

run_tests_on() {
  local platform_label="$1"
  local destination="$2"
  local log_file="/tmp/timeconverter-test-output-${platform_label}.log"

  echo ""
  echo "Running tests (scheme=$SCHEME, platform=$platform_label)..."

  # The Mac lane needs two accommodations the simulator doesn't:
  # - Relax the deployment target to the host's macOS version, in case the
  #   project targets a newer SDK than this machine runs. Test-only override.
  # - Sign ad-hoc with no team: Mac Catalyst test bundles must be codesigned,
  #   and ad-hoc signing works headlessly with no keychain access.
  local extra_settings=()
  if [[ "$platform_label" == "mac" ]]; then
    extra_settings=(
      "MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f1-2)"
      "CODE_SIGN_IDENTITY=-"
      "CODE_SIGN_STYLE=Manual"
      "DEVELOPMENT_TEAM="
      "PROVISIONING_PROFILE_SPECIFIER="
    )
  fi

  # shellcheck disable=SC2086
  xcodebuild test \
    -project "$REPO_DIR/TimeConverter.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "$destination" \
    $ONLY_TESTING \
    ${extra_settings[@]+"${extra_settings[@]}"} \
    2>&1 | tee "$log_file" | tail -25

  # Swift Testing reports "Test run with N tests"; the XCTest "Executed N
  # tests" counter stays at 0 for Swift Testing suites, so prefer the former.
  local summary
  summary=$(grep -E 'Test run with [0-9]+ tests?' "$log_file" | tail -1 || true)
  [[ -n "$summary" ]] || summary=$(grep -E 'Executed [0-9]+ tests?' "$log_file" | tail -1 || true)
  if [[ -n "$summary" ]]; then
    echo ""
    echo "Summary ($platform_label): $summary"
  fi

  if grep -q '^\*\* TEST SUCCEEDED \*\*' "$log_file"; then
    echo "Result ($platform_label): PASS"
    return 0
  else
    echo "Result ($platform_label): FAIL"
    return 1
  fi
}

OVERALL_RESULT=0
case "$PLATFORM" in
  ios)
    run_tests_on ios "$IOS_DESTINATION" || OVERALL_RESULT=1 ;;
  mac)
    run_tests_on mac "$MAC_DESTINATION" || OVERALL_RESULT=1 ;;
  all)
    run_tests_on ios "$IOS_DESTINATION" || OVERALL_RESULT=1
    run_tests_on mac "$MAC_DESTINATION" || OVERALL_RESULT=1 ;;
esac

exit "$OVERALL_RESULT"
