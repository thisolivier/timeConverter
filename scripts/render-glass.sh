#!/usr/bin/env bash
# render-glass.sh — draw the Mac glass panel into PNGs, without a screen.
#
# Backlog item 20, phase B. Screenshotting a Mac app on this machine is blocked
# — screen capture needs TCC consent a headless session cannot give — and the
# glass panel is the first thing this project has built that is *entirely* a
# design, so "the tests pass" says nothing about whether the composition is the
# composition. `ImageRenderer` is the one route to a picture of a SwiftUI view
# that needs no window-server consent.
#
# It renders the real shipping views (`GlassConverterLayout`), in both
# appearances, across the states the design draws and the three it does not:
#
#   phaseB-panel-converted-{light,dark}.png       the design, page 3
#   phaseB-panel-hint-{light,dark}.png            nothing typed yet
#   phaseB-panel-prompt-chips-{light,dark}.png    P4/P5, with corrections
#   phaseB-panel-prompt-plain-{light,dark}.png    P1/P2, no corrections
#   phaseB-dropdown-converted-{light,dark}.png    the stacked narrow fallback
#   phaseB-dropdown-prompt-chips-{light,dark}.png chips at dropdown width
#
# WHAT THESE PICTURES ARE NOT: the glass. An offscreen pass has no window and
# therefore no desktop to blur, so a behind-window NSVisualEffectView draws
# nothing there at all. The renderer substitutes the design's own 42% veil so
# the ink has something to sit on. Layout, type, hierarchy and both appearances
# are all judgeable from these; the frosting, the saturation and the shadow are
# only judgeable on a real desktop — scripts/run-mac.sh, and your eyes.
#
# Usage:
#   scripts/render-glass.sh [output-directory]   # default: build/glass-renders

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TimeConverterMac"
DERIVED_DATA="$REPO_DIR/build/DerivedData"
APP_BINARY="$DERIVED_DATA/Build/Products/Debug/TimeConverter.app/Contents/MacOS/TimeConverter"
OUTPUT_DIR="${1:-$REPO_DIR/build/glass-renders}"

mkdir -p "$OUTPUT_DIR"

(cd "$REPO_DIR" && xcodegen generate --quiet)

xcodebuild build \
  -project "$REPO_DIR/TimeConverter.xcodeproj" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  "MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f1-2)" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  2>&1 | tail -3

echo ""
echo "Rendering into $OUTPUT_DIR"

# `-renderGlass` renders and then terminates, so this is not a GUI launch that
# needs cleaning up — but it is still backstopped, because an app that fails to
# reach its own terminate call would otherwise sit in the menu bar forever.
rm -f "$OUTPUT_DIR"/phaseB-*.png
"$APP_BINARY" -renderGlass "$OUTPUT_DIR" &
RENDER_PID=$!
for _ in $(seq 1 30); do
  kill -0 "$RENDER_PID" 2>/dev/null || break
  sleep 1
done
kill -9 "$RENDER_PID" 2>/dev/null || true
wait "$RENDER_PID" 2>/dev/null || true

RENDERED=$(find "$OUTPUT_DIR" -name 'phaseB-*.png' | wc -l | tr -d ' ')
echo ""
if [[ "$RENDERED" -eq 12 ]]; then
  echo "Rendered $RENDERED images:"
  ls -1 "$OUTPUT_DIR"/phaseB-*.png
  echo ""
  echo "Remember: these show layout and type, not the frosting. For the glass"
  echo "itself: scripts/run-mac.sh, then ⌃⌥T."
else
  echo "Expected 12 images, got $RENDERED — see above for build errors."
  exit 1
fi
