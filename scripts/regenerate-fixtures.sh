#!/usr/bin/env bash
# regenerate-fixtures.sh — rewrite fixtures/conversion-cases.json from the Swift core.
#
# The Swift core is the source of truth for behaviour; this renders the inputs
# in SharedFixtureCatalog.swift through it and writes the shared fixture file
# that BOTH the Swift and the Android test suites assert against. Run it after
# any parser/presenter change that is meant to change output, then run both
# suites (scripts/test.sh, scripts/test-android.sh) and commit the JSON with the
# code — a stale file fails SharedFixtureTests on the Apple side, and a
# regenerated file is the to-do list for the Android port.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR/TimeConverterCore"
if ! TIMECONVERTER_REGENERATE_FIXTURES=1 swift test --filter SharedFixtureTests > "${TMPDIR:-/tmp}/regenerate-fixtures.log" 2>&1; then
  grep -E 'error|failed' "${TMPDIR:-/tmp}/regenerate-fixtures.log" | head -20
  echo "swift test failed — fixtures NOT regenerated"; exit 1
fi
echo "Wrote $REPO_DIR/fixtures/conversion-cases.json ($(grep -c '"id"' "$REPO_DIR/fixtures/conversion-cases.json") cases)"
