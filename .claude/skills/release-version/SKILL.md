---
name: release-version
description: Bump version numbers using semantic versioning when preparing a release. Use when shipping builds, tagging releases, or when version numbers need updating.
allowed-tools: Read, Edit, Bash(git:*), Grep, Glob
---

# Release Version

Bump version numbers using semantic versioning conventions.

## Semantic Versioning Rules

Follow semver `MAJOR.MINOR.PATCH`:

- **PATCH** (X.X.0 → X.X.1): Bug fixes, small corrections, logging improvements, cosmetic changes
- **MINOR** (X.1.X → X.2.0): New features, new endpoints, new views, new capabilities. Resets PATCH to 0.
- **MAJOR** (1.X.X → 2.0.0): Major feature-sets, breaking API changes, architectural overhauls. Resets MINOR and PATCH to 0.

When in doubt, prefer the smaller bump. Only bump MAJOR for genuinely transformative changes.

## Procedure

1. **Determine bump type** from the changes since last version (read recent git log)
2. **Find all version locations** — search the codebase for the current version string. Common places include:
   - Package manifests (`pyproject.toml`, `package.json`, `Cargo.toml`, etc.)
   - App framework constructors (FastAPI `version=`, Express, etc.)
   - Constants or config files that expose version to users (health endpoints, about screens)
   - Mobile app plists or build configs (`CFBundleShortVersionString`, `versionName`, etc.)
   - Build numbers (integers that always increment, independent of semver)
3. **Update ALL locations** — version strings must match everywhere. Missing one causes confusion.
4. **Update the changelog** with user-facing language describing what changed:
   - Good: "Fixed issue where searches could fail silently"
   - Bad: "Refactored JWTSigner to check OID bytes"
5. **Ensure the changelog is visible to users** — apps with a UI should have a screen where users can see the changelog and current version (e.g. in Settings or About).
6. **Commit** with message: `Bump {component} to vX.Y.Z`

## Common Pitfalls

- Forgetting a version location — always grep for the old version string before committing
- Bumping MAJOR for what's really a MINOR change — reserve MAJOR for breaking or transformative changes
- Not resetting lower segments (MINOR bump should reset PATCH to 0)
- Build numbers should always increment, even for patch releases
