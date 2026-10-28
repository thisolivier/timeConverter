#!/usr/bin/env bash
# test-android.sh: the Android lane's tests, one command.
#
#   scripts/test-android.sh                 # JVM unit tests: :core + :app (seconds, no emulator)
#   scripts/test-android.sh --instrumented  # also on-device tests, on the running emulator
#   scripts/test-android.sh GreetingTest    # one class (bare names mean :core)
set -euo pipefail
source "$(dirname "$0")/lib/android-env.sh"
cd "$ANDROID_PROJECT_DIR"

INSTRUMENTED=false
FILTER=()
for argument in "$@"; do
  case "$argument" in
    --instrumented) INSTRUMENTED=true ;;
    --help|-h) sed -n '2,7p' "$0"; exit 0 ;;
    *) FILTER=(--tests "*${argument}*") ;;
  esac
done

# --rerun so a cached green run still prints its per-test lines.
if [[ ${#FILTER[@]} -gt 0 ]]; then
  TASKS=(:core:test --rerun "${FILTER[@]}")
else
  TASKS=(:core:test --rerun :app:testDebugUnitTest --rerun)
fi
$INSTRUMENTED && TASKS+=(:app:connectedDebugAndroidTest)

# grep would otherwise hide gradle's exit status: read it from PIPESTATUS on
# the right of `||`. (A trailing `|| true` then `GRADLE_EXIT=${PIPESTATUS[0]}`
# reads the status of `true`, i.e. 0, and silently passes failing tests.)
GRADLE_EXIT=0
./gradlew "${TASKS[@]}" --console=plain 2>&1 | grep -E 'PASSED|FAILED|SKIPPED|BUILD|error:|e: ' \
  || GRADLE_EXIT=${PIPESTATUS[0]}
[[ $GRADLE_EXIT -eq 0 ]] || { echo "FAILED (gradle exit $GRADLE_EXIT)"; exit "$GRADLE_EXIT"; }
