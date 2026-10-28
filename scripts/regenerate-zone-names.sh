#!/usr/bin/env bash
# regenerate-zone-names.sh — capture iOS's zone names into the shared snapshot.
#
# Rewrites TimeConverterCore/Sources/TimeConverterCore/Resources/zone-names.json
# from what the iOS SIMULATOR answers for every known tz identifier
# (TimeZone.localizedName(for: .generic, locale: en_US)). iOS is the origin:
# macOS and Android render from this file instead of asking their own ICU, so
# it must never be captured anywhere else — hence no --platform mac.
#
# `xcodebuild test` does not pass environment variables into the test host, so
# regenerate mode is keyed on a marker file (fixtures/.regenerate-zone-names)
# that ZoneNameSnapshotTests looks for; it is removed on exit, success or not.
#
# Afterwards: scripts/regenerate-fixtures.sh (the fixture zone lines embed these
# names), then scripts/test.sh --platform all and scripts/test-android.sh.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
for argument in "$@"; do
  if [[ "$argument" == "--platform" || "$argument" == mac || "$argument" == all ]]; then
    echo "Error: zone names are captured on iOS only (iOS is the origin); no --platform option." >&2
    exit 1
  fi
done
MARKER="$REPO_DIR/fixtures/.regenerate-zone-names"
trap 'rm -f "$MARKER"' EXIT
touch "$MARKER"
"$REPO_DIR/scripts/test.sh" ZoneNameSnapshotTests
SNAPSHOT="$REPO_DIR/TimeConverterCore/Sources/TimeConverterCore/Resources/zone-names.json"
echo "Wrote $SNAPSHOT ($(grep -c '" : "' "$SNAPSHOT") zones)"
