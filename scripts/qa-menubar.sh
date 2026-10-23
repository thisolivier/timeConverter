#!/usr/bin/env bash
# qa-menubar.sh — QA the native Mac menu-bar app and ⌃⌥T (backlog item 16).
#
# Successor to the item-12a version, which QA'd a macOS-SDK bundle loaded into a
# Catalyst process. There is no bundle any more, so the checks that proved it
# was placed in Contents/PlugIns, was a macOS binary, cast across the `@objc`
# protocol boundary, and degraded gracefully when absent are all gone — their
# failure modes went with the architecture. What is left is what still matters:
# the status item, the hotkey registration, process hygiene, and the one thing
# a script cannot do.
#
# Debug only, this machine only, and deliberately NOT part of scripts/test.sh:
# it launches and kills a GUI app and touches the real menu bar.
#
# Synthetic keystroke injection stays off the table: it is TCC-blocked
# (osascript hangs on an Accessibility consent prompt a locked screen cannot
# answer), and granting Accessibility to an automation harness to test a hotkey
# is a far bigger blast radius than the feature. So the last step prints what to
# press and everything around it is asserted — including that registration
# returned noErr, which is necessary but NOT sufficient.
#
# Usage: scripts/qa-menubar.sh

set -uo pipefail  # not -e: every step reports, then the script sums up

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$REPO_DIR/build/DerivedData/Build/Products/Debug/TimeConverter.app"
APP_BINARY="$APP_PATH/Contents/MacOS/TimeConverter"
# Matches only this build's process, so a copy of the app running from
# /Applications cannot be mistaken for the one under test — or killed by it.
PROCESS_PATTERN="Products/Debug/TimeConverter.app/Contents/MacOS/TimeConverter"
LOG_PREDICATE='subsystem == "dev.thisolivier.timeconverter" AND category == "menubar"'

FAILURES=0
STEP=0

step() { STEP=$((STEP + 1)); printf '\n%s. %s\n' "$STEP" "$1"; }
pass() { printf '   PASS  %s\n' "$1"; }
fail() { printf '   FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
note() { printf '   ....  %s\n' "$1"; }

# `pgrep -c` is a Linux flag; BSD pgrep prints usage and exits 2, so count by
# hand.
instance_count() { pgrep -f "$PROCESS_PATTERN" 2>/dev/null | wc -l | tr -d ' '; }

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

echo "QA: native Mac menu bar + ⌃⌥T (item 16)"

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

step "Shape — a native macOS binary with no Dock presence"
if vtool -show-build "$APP_BINARY" 2>/dev/null | grep -q "platform MACOS"; then
  pass "app binary: platform MACOS (not MACCATALYST)"
else
  fail "app binary is not a native macOS binary"
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_PATH/Contents/Info.plist" 2>/dev/null)" == "true" ]]; then
  pass "LSUIElement — no Dock icon, no app menu bar, no window on launch"
else
  fail "LSUIElement is not set; the app would acquire a Dock icon"
fi

step "Launch — the app says what actually came up"
launch_and_wait
if [[ -n "$LAST_LAUNCH_LOG" ]]; then note "$LAST_LAUNCH_LOG"; fi
if grep -q "menu bar ready" <<<"$LAST_LAUNCH_LOG"; then
  pass "menu bar started"
else
  fail "no 'menu bar ready' log line"
fi
# The app reports what it can actually observe (a status-bar window in this
# process), so this is an assertion rather than a tautology: "no status item"
# fails this grep.
if grep -q -- "— status item +" <<<"$LAST_LAUNCH_LOG"; then
  pass "MenuBarExtra status item placed in the menu bar"
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

   Expect: the glass panel of design page 3 appears, centred — 740pt wide,
   frosted, 30pt corners, NO title bar and no close button, with the cursor in
   the big mono line at the top. Type "8pm Lisbon in Sao Paulo" and the
   FROM/TO pair fills the middle side by side, with the footer sentence
   underneath. The desktop must be visibly blurred *through* the panel, and
   must change as you drag the panel over different wallpaper — that is the
   behind-window material, and it is the one thing no offscreen render can
   prove (see scripts/render-glass.sh for what they can).

   Press ⌃⌥T again while looking at it and it goes away (SummonPolicy: a
   toggle only toggles when you can already see it). Press it from another app
   while the panel is open and it comes forward instead. Esc dismisses it.
   Clicking the clock glyph must open the dropdown with its own focused field,
   the same design at 400pt with the pair stacked vertically. Every press logs
   a 'hotkey received' line:

     log show --predicate 'subsystem == "dev.thisolivier.timeconverter"' \
       --last 2m --style compact

   That line is what separates "the keystroke never arrived" (nothing logged —
   suspect screen-share key forwarding) from "the summon failed" (logged, no
   panel).
MANUAL

printf '\n'
if [[ $FAILURES -eq 0 ]]; then
  echo "RESULT: all headless checks passed (the manual keypress above is still owed)"
else
  echo "RESULT: $FAILURES check(s) FAILED"
fi
exit "$FAILURES"
