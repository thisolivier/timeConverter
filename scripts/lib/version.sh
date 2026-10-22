#!/usr/bin/env bash
# lib/version.sh — the ONE place that reads and writes the build number.
#
# `project.yml`'s project-level `settings.base.CURRENT_PROJECT_VERSION` is the
# single source of truth for CFBundleVersion across the app, the Controls
# extension and the menu-bar bundle (each Info.plist carries the
# `$(CURRENT_PROJECT_VERSION)` placeholder rather than a literal).
#
# It is shared rather than copied because there are now two ship lanes —
# `scripts/ship.sh` (iOS) and `scripts/ship-mac.sh` (Mac Catalyst) — uploading
# into two platform trains of the *same* App Store Connect record, and a
# build number that drifts between them is a class of bug Apple only reports
# at the altool stage (ITMS-90189), long after archive and export have both
# said "succeeded". macOS is the stricter of the two: its CFBundleVersion must
# increase monotonically across *all* version trains, so a number burned on a
# failed Mac upload is unrecoverable.
#
# Sourcing contract: the sourcing script must already define `fail <step>`
# (print and exit non-zero). Both ship scripts do.

# read_build_number <project.yml> -> echoes the current CURRENT_PROJECT_VERSION
#
# Matches the first occurrence, which is the project-level `settings.base`
# entry. No target overrides it, by design.
read_build_number() {
  local project_yml="$1"
  grep -m1 'CURRENT_PROJECT_VERSION:' "$project_yml" \
    | sed -E 's/.*CURRENT_PROJECT_VERSION: *"?([0-9]+)"?.*/\1/'
}

# bump_build_number <project.yml> <new-build-number>
#
# Patches project.yml in place (never the generated pbxproj — that would be
# silently wiped by the next `xcodegen generate`), enforces monotonicity, and
# reads the file back to prove the edit landed.
bump_build_number() {
  local project_yml="$1"
  local new_build_number="$2"

  if [[ ! -f "$project_yml" ]]; then
    fail "version bump (project.yml not found at $project_yml)"
  fi

  local current_build_number
  current_build_number="$(read_build_number "$project_yml")"
  if [[ -z "$current_build_number" ]]; then
    fail "version bump (could not find CURRENT_PROJECT_VERSION in project.yml)"
  fi

  # CFBundleVersion must be strictly monotonic — Apple rejects a redundant build
  # number at the *altool* stage (ITMS-90189), long after archive and export have
  # both reported success.
  if [[ "$new_build_number" -le "$current_build_number" ]]; then
    echo "Error: build number must increase. project.yml is at"
    echo "       $current_build_number, asked to ship $new_build_number."
    echo "       Apple rejects duplicate/declining build numbers (ITMS-90189)."
    fail "version bump (non-monotonic build number)"
  fi

  sed -i '' -E \
    "s/CURRENT_PROJECT_VERSION: \"?${current_build_number}\"?/CURRENT_PROJECT_VERSION: \"${new_build_number}\"/" \
    "$project_yml"

  local verified_build_number
  verified_build_number="$(read_build_number "$project_yml")"
  if [[ "$verified_build_number" != "$new_build_number" ]]; then
    fail "version bump (expected CURRENT_PROJECT_VERSION=$new_build_number after sed, found '$verified_build_number')"
  fi
  echo "Bumped CURRENT_PROJECT_VERSION: $current_build_number → $new_build_number (in project.yml)"
}
