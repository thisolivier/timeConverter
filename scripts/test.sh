#!/usr/bin/env bash
# test.sh — run TimeConverter's xcodebuild tests.
#
# Adapted from musicLibrary/iOSnative/scripts/test.sh. Two lanes, one scheme
# each, since the native restructure (backlog item 16):
#
#   ios   scheme TimeConverter      iOS simulator. The iOS shell's own tests
#                                   (TimeConverterTests) + the whole
#                                   TimeConverterCore package test target, run
#                                   on iOS.
#   mac   scheme TimeConverterMac   This Mac, natively. The Mac shell's own
#                                   tests (TimeConverterMacTests) + the same
#                                   TimeConverterCore test target, run on
#                                   macOS — and, because `xcodebuild test`
#                                   builds the scheme, proof that the native
#                                   menu-bar app still compiles.
#
# The shared core is therefore tested twice, once per platform, which is the
# point: in the sibling projects the Mac build shipped broken while the iPhone
# lane was green. Run --platform all before shipping anything that touches
# parsing, the presenter, or startup wiring.
#
# Usage:
#   scripts/test.sh                                    # iOS sim, all tests
#   scripts/test.sh PromptTests                        # one core suite, iOS
#   scripts/test.sh TimeConverterTests/InputFocusPolicyTests
#   scripts/test.sh --platform mac                     # native macOS, all
#   scripts/test.sh --platform all                     # both platforms
#   scripts/test.sh --help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IOS_SCHEME="TimeConverter"
MAC_SCHEME="TimeConverterMac"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17"
# Plain `platform=macOS` — no `variant=Mac Catalyst`. TimeConverterMac is a
# native macOS target; asking for the Catalyst variant would fail outright.
MAC_DESTINATION="platform=macOS,arch=arm64"
# Where the overwhelming majority of the tests live, so a bare class name on
# the command line means this one.
DEFAULT_TEST_TARGET="TimeConverterCoreTests"

usage() {
  echo "Usage: $0 [--platform ios|mac|all] [[TestTarget/]TestClassName]"
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

# A bare `PromptTests` is assumed to be a core suite; anything already carrying
# a `Target/` prefix is passed through untouched, which is how the two shells'
# own suites are reachable.
ONLY_TESTING=""
if [[ ${#POSITIONAL[@]} -ge 1 ]]; then
  SELECTOR="${POSITIONAL[0]}"
  [[ "$SELECTOR" == */* ]] || SELECTOR="$DEFAULT_TEST_TARGET/$SELECTOR"
  ONLY_TESTING="-only-testing:$SELECTOR"
fi

# The .xcodeproj is not tracked in git — regenerate it from project.yml.
(cd "$REPO_DIR" && xcodegen generate --quiet)

run_tests_on() {
  local platform_label="$1"
  local scheme="$2"
  local destination="$3"
  local log_file="/tmp/timeconverter-test-output-${platform_label}.log"

  echo ""
  echo "Running tests (scheme=$scheme, platform=$platform_label)..."

  # The Mac lane needs two accommodations the simulator doesn't:
  # - Relax the deployment target to the host's macOS version, in case the
  #   project targets a newer SDK than this machine runs. Test-only override.
  # - Sign ad-hoc with no team: macOS test bundles and app hosts must be
  #   codesigned, and ad-hoc signing works headlessly with no keychain access.
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
    -scheme "$scheme" \
    -destination "$destination" \
    $ONLY_TESTING \
    ${extra_settings[@]+"${extra_settings[@]}"} \
    2>&1 | tee "$log_file" | tail -25

  # Swift Testing reports "Test run with N tests" once per test *bundle*, and
  # both lanes run two bundles (a shell's own plus the core package), so the
  # lines are summed rather than tail -1'd. The XCTest "Executed N tests"
  # counter stays at 0 for Swift Testing suites.
  local summary
  summary=$(grep -E 'Test run with [0-9]+ tests?' "$log_file" \
    | grep -oE 'with [0-9]+ test' | grep -oE '[0-9]+' \
    | awk '{total += $1} END {if (NR) print total " tests across " NR " bundle(s)"}')
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
    run_tests_on ios "$IOS_SCHEME" "$IOS_DESTINATION" || OVERALL_RESULT=1 ;;
  mac)
    run_tests_on mac "$MAC_SCHEME" "$MAC_DESTINATION" || OVERALL_RESULT=1 ;;
  all)
    run_tests_on ios "$IOS_SCHEME" "$IOS_DESTINATION" || OVERALL_RESULT=1
    run_tests_on mac "$MAC_SCHEME" "$MAC_DESTINATION" || OVERALL_RESULT=1 ;;
esac

exit "$OVERALL_RESULT"
