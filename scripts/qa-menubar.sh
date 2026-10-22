#!/usr/bin/env bash
# qa-menubar.sh — QA the Mac menu-bar presence and ⌃⌥T (backlog item 12a).
#
# Debug only, this machine only, and deliberately NOT part of scripts/test.sh:
# it launches and kills a GUI app and touches the real menu bar, which has no
# place in a unit-test lane.
#
# Everything here is headless except the one thing that cannot be: a literal
# keypress. Synthetic keystroke injection is TCC-blocked (osascript hangs
# waiting for an Accessibility consent prompt that a locked screen cannot
# answer), and granting Accessibility to an automation harness purely to test a
# hotkey would be a far bigger blast radius than the feature. So step 7 prints
# what to press and this script asserts everything around it — including that
# registration returned noErr, which is necessary but NOT sufficient:
# RegisterEventHotKey also returns noErr for a combo the system already owns.
#
# Usage: scripts/qa-menubar.sh

set -uo pipefail  # not -e: every step reports, then the script sums up

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_DIR/build/DerivedData/Build/Products/Debug-maccatalyst/TimeConverter.app"
PLUGIN_PATH="$APP_PATH/Contents/PlugIns/TimeConverterMenuBar.bundle"
PLUGIN_BINARY="$PLUGIN_PATH/Contents/MacOS/TimeConverterMenuBar"
# Matches only this build's process, so a copy of the app running from
# /Applications cannot be mistaken for the one under test — or killed by it.
PROCESS_PATTERN="Debug-maccatalyst/TimeConverter.app/Contents/MacOS/TimeConverter"
LOG_PREDICATE='subsystem == "dev.thisolivier.timeconverter" AND category == "menubar"'

FAILURES=0
STEP=0

step() { STEP=$((STEP + 1)); printf '\n%s. %s\n' "$STEP" "$1"; }
pass() { printf '   PASS  %s\n' "$1"; }
fail() { printf '   FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
note() { printf '   ....  %s\n' "$1"; }

# `pgrep -c` is a Linux flag; BSD pgrep prints usage and exits 2, so count by
# hand. The pattern is the full binary path, which also means it cannot match
# an older build of this app whose product was named differently.
instance_count() { pgrep -f "$PROCESS_PATTERN" 2>/dev/null | wc -l | tr -d ' '; }

# The app logs through os.Logger, so the log is readable after the fact rather
# than only on a terminal that owns the process.
menubar_log_since() {
  /usr/bin/log show --predicate "$LOG_PREDICATE" --start "$1" --style compact 2>/dev/null \
    | grep -E "menu bar (ready|unavailable)"
}

launch_and_wait() {
  local since
  since="$(date '+%Y-%m-%d %H:%M:%S')"
  open ${1:-} "$APP_PATH"
  local waited=0
  while [[ $waited -lt 20 ]]; do
    if menubar_log_since "$since" | grep -q "menu bar"; then break; fi
    sleep 0.5
    waited=$((waited + 1))
  done
  LAST_LAUNCH_LOG="$(menubar_log_since "$since")"
}

kill_all_instances() {
  pkill -f "$PROCESS_PATTERN" 2>/dev/null
  local waited=0
  while [[ $(instance_count) -ne 0 && $waited -lt 20 ]]; do sleep 0.5; waited=$((waited + 1)); done
}

echo "QA: Mac menu bar + ⌃⌥T (item 12a)"

step "Pre-flight — no instance of this build already running"
if [[ $(instance_count) -eq 0 ]]; then
  pass "none running"
else
  fail "$(instance_count) already running — quit it first (a second instance makes which process receives a press undefined)"
  exit 1
fi

step "Collision snapshot — does the system already own ⌃⌥T?"
if swift "$REPO_DIR/scripts/menubar-hotkey-collision.swift" | sed 's/^/   /'; then
  pass "⌃⌥T free of enabled system symbolic hotkeys"
else
  fail "⌃⌥T collides with a system symbolic hotkey"
fi

step "Build and launch (same path as scripts/run-mac.sh)"
if "$REPO_DIR/scripts/run-mac.sh" >/dev/null 2>&1; then
  pass "built and launched"
else
  fail "build/launch failed — run scripts/run-mac.sh to see why"
  exit 1
fi
kill_all_instances  # run-mac.sh already launched it; relaunch below with logging

step "Placement — the bundle is where builtInPlugInsURL looks, and is a macOS binary"
if [[ -d "$PLUGIN_PATH" ]]; then
  pass "Contents/PlugIns/$(basename "$PLUGIN_PATH")"
else
  fail "missing $PLUGIN_PATH (a wrong 'copy:' in project.yml lands it in Contents/Resources)"
fi
if vtool -show-build "$PLUGIN_BINARY" 2>/dev/null | grep -q "platform MACOS"; then
  pass "bundle binary: platform MACOS"
else
  fail "bundle binary is not a macOS binary"
fi
if vtool -show-build "$APP_PATH/Contents/MacOS/TimeConverter" 2>/dev/null | grep -q "platform MACCATALYST"; then
  pass "host binary: platform MACCATALYST"
else
  fail "host binary is not a Catalyst binary"
fi

step "Load + registration — the app says what came up"
launch_and_wait
if [[ -n "$LAST_LAUNCH_LOG" ]]; then note "$LAST_LAUNCH_LOG"; fi
if grep -q "menu bar ready" <<<"$LAST_LAUNCH_LOG"; then
  pass "bundle loaded, principal class cast to MenuBarHosting"
else
  fail "no 'menu bar ready' log line"
fi
# The bundle reports what actually came up, so this is an assertion rather than
# a tautology: it says "status item" only when NSStatusBar gave a button *and*
# AppKit placed it in a status-bar window. "no status item" and "status item
# (created but not placed…)" both fail this grep.
if grep -q -- "— status item +" <<<"$LAST_LAUNCH_LOG"; then
  pass "status item placed in the menu bar"
else
  fail "status item did not appear — see the log line above"
fi
if grep -q "status item + ⌃⌥T" <<<"$LAST_LAUNCH_LOG"; then
  pass "hotkey registered (noErr)"
else
  fail "hotkey not registered — see the log line above"
fi

step "Single instance, and what it costs"
if [[ $(instance_count) -eq 1 ]]; then
  pass "exactly one process"
else
  fail "$(instance_count) processes — a press would go somewhere undefined"
fi
note "$(ps -o rss=,pcpu=,comm= -p "$(pgrep -f "$PROCESS_PATTERN" | head -1)" 2>/dev/null \
  | awk '{printf "RSS %.1f MB, CPU %s%%", $1/1024, $2}')"

step "A second instance must be harmless"
launch_and_wait -n
if [[ -n "$LAST_LAUNCH_LOG" ]]; then note "$LAST_LAUNCH_LOG"; fi
if [[ $(instance_count) -eq 2 ]]; then
  pass "two processes, both alive"
  note "a second registration is non-fatal either way: a cross-process duplicate"
  note "returns noErr and both live (which press goes where is then undefined —"
  note "hence the single-instance assertion before any manual press), while an"
  note "exclusive holder returns eventHotKeyExistsErr, which the code reports as"
  note "'no hotkey' and carries on with a clickable status item"
else
  fail "expected 2 processes after 'open -n', saw $(instance_count)"
fi
kill_all_instances

step "Orderly teardown, then re-register"
if [[ $(instance_count) -eq 0 ]]; then
  pass "quit leaves no process (and the status item goes with it)"
else
  fail "process survived termination"
fi
launch_and_wait
if grep -q "status item + ⌃⌥T" <<<"$LAST_LAUNCH_LOG"; then
  pass "re-registered after quit"
else
  fail "could not re-register after quit: $LAST_LAUNCH_LOG"
fi

step "Crash path — kill -9 strands nothing"
pkill -9 -f "$PROCESS_PATTERN" 2>/dev/null
while [[ $(instance_count) -ne 0 ]]; do sleep 0.5; done
launch_and_wait
if grep -q "status item + ⌃⌥T" <<<"$LAST_LAUNCH_LOG"; then
  pass "re-registered after SIGKILL (the system reclaims per-process WindowServer state)"
else
  fail "could not re-register after SIGKILL: $LAST_LAUNCH_LOG"
fi
kill_all_instances

step "Negative path — the app must run fine with no bundle at all"
mv "$PLUGIN_PATH" "$PLUGIN_PATH.qa-moved"
launch_and_wait
if [[ -n "$LAST_LAUNCH_LOG" ]]; then note "$LAST_LAUNCH_LOG"; fi
if grep -q "menu bar unavailable" <<<"$LAST_LAUNCH_LOG"; then
  pass "logged the failure and continued"
else
  fail "expected a 'menu bar unavailable' log line"
fi
if [[ $(instance_count) -eq 1 ]]; then
  pass "app is running without a menu bar"
else
  fail "app did not survive a missing bundle"
fi
kill_all_instances
mv "$PLUGIN_PATH.qa-moved" "$PLUGIN_PATH"

step "Clean exit — nothing left running, no hotkey state stranded"
if [[ $(instance_count) -eq 0 ]]; then
  pass "no processes left"
else
  fail "$(instance_count) processes left running"
fi
if swift "$REPO_DIR/scripts/menubar-hotkey-collision.swift" >/dev/null; then
  pass "⌃⌥T free again"
else
  fail "⌃⌥T still claimed after exit"
fi

step "MANUAL — the one thing a script cannot do"
cat <<'MANUAL'
   Registration returning noErr is not proof that a press fires. On an
   unlocked screen, with the app running:

     scripts/run-mac.sh
     # click some other app, then press ⌃⌥T

   Expect: TimeConverter comes forward, the field is focused, and anything
   already typed in it is STILL THERE (unlike the Control Center control,
   which clears it). Clicking the clock glyph in the menu bar must do the
   same. Then ⌘Q and watch the glyph disappear.
MANUAL

printf '\n'
if [[ $FAILURES -eq 0 ]]; then
  echo "RESULT: all headless checks passed (the manual keypress above is still owed)"
else
  echo "RESULT: $FAILURES check(s) FAILED"
fi
exit "$FAILURES"
