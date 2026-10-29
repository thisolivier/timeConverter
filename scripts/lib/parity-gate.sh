#!/usr/bin/env bash
# lib/parity-gate.sh — the shared-core release gate that EVERY ship lane runs.
#
# Three apps, one behaviour. The contract is fixtures/conversion-cases.json:
# the Swift core generates it, and both the Swift and the Kotlin suites assert
# against it exactly. A lane may only ship when the whole chain holds:
#
#   Swift core  ──SharedFixtureTests──▶  fixtures file  ◀──SharedFixture*Tests──  Kotlin core
#
# Android build 17 (2026-10-28) shipped without `now` and Antarctica because
# the Kotlin parser half of that chain was `@Ignore`d and nothing refused to
# ship on a skipped test. This file is the refusal.
#
# It also keeps docs/releases.md, a per-lane log of what shipped from which
# commit, so a lane can see when the core moved on since another lane last
# shipped — the "ship all lanes when core changes" rule, made visible.
#
# Sourcing contract: REPO_DIR is set. Functions return non-zero on failure and
# print why; callers wrap them in `|| fail "<step>"`.

PARITY_RELEASE_LOG="$REPO_DIR/docs/releases.md"
# Paths whose change means "the shared behaviour moved": the Swift core
# sources (parser, engine, resources) and the generated contract itself.
PARITY_CORE_PATHS=("TimeConverterCore/Sources" "fixtures/conversion-cases.json" "fixtures/world-clock-cases.json")

# parity_gate_swift_core — runs the Swift core package suite.
#
# SharedFixtureTests fails when the fixture file no longer matches what the
# Swift core produces, i.e. when a core change was committed without
# scripts/regenerate-fixtures.sh. Fast (seconds once built) and needs no
# simulator, which is why every lane can afford it, Android included.
parity_gate_swift_core() {
  local log_file="${TMPDIR:-/tmp}/timeconverter-parity-swift.log"
  echo "Swift core suite (parser tests + fixture contract)..."
  if ! swift test --package-path "$REPO_DIR/TimeConverterCore" > "$log_file" 2>&1; then
    grep -E '✘|error:|Expectation failed' "$log_file" | head -20
    echo "Swift core suite failed (full log: $log_file)."
    echo "If SharedFixtureTests is the failure, the fixtures are stale: run"
    echo "scripts/regenerate-fixtures.sh, review the diff, commit, then ship again."
    return 1
  fi
  grep -E 'Test run with .* passed' "$log_file" | tail -1
}

# parity_gate_kotlin_fixtures — reads the JUnit reports scripts/test-android.sh
# just produced and refuses when the shared-fixture classes ran nothing,
# skipped anything, or failed anything. A green Gradle run with a skipped
# fixture class is precisely the hole this closes.
parity_gate_kotlin_fixtures() {
  local reports_dir="$REPO_DIR/TimeConverterAndroid/core/build/test-results/test"
  local report_count=0 report_file suite_line tests skipped failures errors class_name
  for report_file in "$reports_dir"/TEST-*SharedFixture*.xml; do
    [[ -f "$report_file" ]] || continue
    report_count=$((report_count + 1))
    suite_line="$(grep -m1 '<testsuite ' "$report_file")"
    class_name="$(sed -nE 's/.* name="([^"]+)".*/\1/p' <<<"$suite_line" | sed 's/.*\.//')"
    tests="$(sed -nE 's/.* tests="([0-9]+)".*/\1/p' <<<"$suite_line")"
    skipped="$(sed -nE 's/.* skipped="([0-9]+)".*/\1/p' <<<"$suite_line")"
    failures="$(sed -nE 's/.* failures="([0-9]+)".*/\1/p' <<<"$suite_line")"
    errors="$(sed -nE 's/.* errors="([0-9]+)".*/\1/p' <<<"$suite_line")"
    echo "$class_name: tests=$tests skipped=$skipped failures=$failures errors=$errors"
    if [[ -z "$tests" || "$tests" -eq 0 || "${skipped:-1}" -ne 0 || "${failures:-1}" -ne 0 || "${errors:-1}" -ne 0 ]]; then
      echo "$class_name must run every shared fixture and pass: nothing skipped, nothing ignored."
      return 1
    fi
  done
  if [[ "$report_count" -lt 2 ]]; then
    echo "Expected the SharedFixtureEngineTests and SharedFixtureParserTests reports under $reports_dir"
    echo "(found $report_count). Run scripts/test-android.sh first."
    return 1
  fi
  if grep -rn '@Ignore' "$REPO_DIR/TimeConverterAndroid/core/src/test" --include='*.kt' | grep -i fixture; then
    echo "A shared-fixture test is @Ignore'd. Un-ignore it and make it pass before shipping."
    return 1
  fi
}

# record_release <lane> <build> <version> <commit> <artifact-note>
#
# Appends one row to docs/releases.md. Called only after a real upload or
# publish succeeded (never on --dry-run / --skip-upload / --validate-only).
record_release() {
  local lane="$1" build_number="$2" version="$3" commit_sha="$4" artifact_note="$5"
  if [[ ! -f "$PARITY_RELEASE_LOG" ]]; then
    echo "No release log at $PARITY_RELEASE_LOG" >&2
    return 1
  fi
  printf '| %s | %s | %s | %s | %s | %s |\n' \
    "$(date +%Y-%m-%d)" "$lane" "$build_number" "$version" "$commit_sha" "$artifact_note" \
    >> "$PARITY_RELEASE_LOG"
  echo "Recorded in docs/releases.md: $lane build $build_number from $commit_sha"
}

# latest_release_row <lane> -> echoes the newest row for that lane (by build)
latest_release_row() {
  local lane="$1"
  grep -E "^\| [0-9]{4}-[0-9]{2}-[0-9]{2} \| $lane \| " "$PARITY_RELEASE_LOG" \
    | sort -t'|' -k4,4n | tail -1
}

# report_lane_drift <lane-just-shipped> <build>
#
# For every OTHER lane: has the shared core changed since it last shipped? If
# so, say which lane is behind and by what. Advisory, never fatal — the rule
# is "ship all lanes when core changes", and this is the reminder at the one
# moment someone is already shipping.
report_lane_drift() {
  local shipped_lane="$1" shipped_build="$2"
  local lane row lane_build lane_commit changed_files behind=0
  echo ""
  echo "Core parity across lanes (docs/releases.md):"
  for lane in ios mac android; do
    [[ "$lane" == "$shipped_lane" ]] && continue
    row="$(latest_release_row "$lane")"
    if [[ -z "$row" ]]; then
      echo "  $lane: never shipped"
      behind=1
      continue
    fi
    lane_build="$(awk -F'|' '{gsub(/ /,"",$4); print $4}' <<<"$row")"
    lane_commit="$(awk -F'|' '{gsub(/ /,"",$6); print $6}' <<<"$row")"
    if ! git -C "$REPO_DIR" cat-file -e "$lane_commit^{commit}" 2>/dev/null; then
      echo "  $lane: build $lane_build from unknown commit $lane_commit — cannot compare"
      continue
    fi
    changed_files="$(git -C "$REPO_DIR" diff --name-only "$lane_commit" HEAD -- "${PARITY_CORE_PATHS[@]}" | wc -l | tr -d ' ')"
    if [[ "$changed_files" -gt 0 ]]; then
      echo "  $lane: build $lane_build is BEHIND — $changed_files core file(s) changed since $lane_commit. Ship $lane at build $shipped_build too."
      behind=1
    else
      echo "  $lane: build $lane_build, core unchanged since — in parity"
    fi
  done
  [[ "$behind" -eq 0 ]] && echo "  all lanes carry the same core"
  return 0
}
