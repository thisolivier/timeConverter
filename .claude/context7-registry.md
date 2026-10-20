# Context7 Library Registry

Libraries tracked for this project. Used by the `context7` skill to look up documentation without re-resolving IDs each time.

## How this file works

- **context7_id**: The Context7-compatible library identifier (resolved via `resolve-library-id`)
- **version**: The version currently used in this project (from package.json, Cargo.toml, etc.)
- **verified**: Date the version was last checked against the project's dependency files
- **status**: `active` (in use), `not-found` (Context7 doesn't have it), `removed` (no longer a dependency)

## Registry

| Library | context7_id | Version | Verified | Status |
|---------|-------------|---------|----------|--------|

## Notes

