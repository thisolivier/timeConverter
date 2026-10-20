---
name: context7
description: Fetch up-to-date library documentation using Context7 MCP. Use proactively whenever working with libraries, APIs, frameworks, or SDKs — for documentation lookup, code generation, setup, configuration, or troubleshooting. Also use when the user says "check docs", "look up API", "how does X work", or references any library/framework.
---

# Context7 Documentation Skill

Fetch version-specific, up-to-date documentation for any library or framework using the Context7 MCP server. This skill is used **proactively** — you do not need to wait for the user to ask for docs.

## When to use this skill

Use Context7 **automatically** whenever you:
- Need to write code using a library's API
- Are generating setup or configuration steps
- Need to verify correct function signatures, options, or patterns
- Are troubleshooting library-related errors
- Are unsure about current API conventions (your training data may be outdated)
- Are working with any dependency listed in the project's package manager files

**Do NOT use** for general programming concepts, language builtins, or topics unrelated to specific libraries.

## Instructions

### Step 1: Check the registry

Before calling Context7, read `.claude/context7-registry.md` to see if the library already has a known Context7 identifier.

If the library is listed with a `context7_id`, skip to **Step 3**.

### Step 2: Resolve the library ID

If the library is **not** in the registry, use the Context7 MCP tool to resolve it:

```
Tool: mcp__context7__resolve-library-id
Input: { "libraryName": "<library-name>" }
```

**Tips for resolving:**
- Use the npm/PyPI/crates.io package name (e.g., `react`, `express`, `tauri`)
- If the first attempt fails, try the full name (e.g., `@tauri-apps/api` instead of `tauri`)
- For monorepo packages, try both the scope and the individual package

Once resolved, **immediately register** the library — see Step 5.

### Step 3: Fetch documentation

Use the Context7 MCP tool to get documentation:

```
Tool: mcp__context7__get-library-docs
Input: {
  "context7CompatibleLibraryID": "<context7_id from registry>",
  "topic": "<specific topic you need>"
}
```

**Topic tips:**
- Be specific: `"useEffect hook"` not `"hooks"`
- Include the operation: `"file upload configuration"` not `"files"`
- For setup: `"getting started"` or `"installation"`

### Step 4: Apply the documentation

- Use the fetched docs to write correct, up-to-date code
- Prefer patterns shown in the official docs over patterns from training data
- If the docs show a different API than expected, trust the docs

### Step 5: Update the registry

After resolving a new library or fetching docs, update `.claude/context7-registry.md`:

1. Read the current registry file
2. Add or update the entry with:
   - Library name (package manager name)
   - Context7 ID (from resolve step)
   - Version currently in use (from package.json, Cargo.toml, etc.)
   - Date last verified
3. Write the updated registry

**Registry entry format:**

```markdown
| library-name | /org/repo | 1.2.3 | 2025-01-15 |
```

### Step 6: Version checking (periodic)

At the **start of each session** and whenever you read a package manager file (package.json, Cargo.toml, etc.):

1. Read the registry at `.claude/context7-registry.md`
2. Read the project's dependency file(s)
3. Compare versions for all registered libraries
4. For any mismatch:
   - **Warn the user**: "Library X version changed: registry says 1.2.3, project uses 2.0.0"
   - **Auto-update the registry** with the new version and today's date
   - **Re-fetch docs** if the major version changed (API may have breaking changes)

## Error handling

- **Context7 MCP not available**: Inform the user that the Context7 plugin needs to be enabled. They can enable it via `/install-plugin context7` or by adding `"context7@context7": true` to `enabledPlugins` in `~/.claude/settings.json`.
- **Library not found**: Try alternative names (scoped, unscoped, org name). If still not found, note it in the registry as `NOT_FOUND` so we don't retry every time.
- **Rate limited or timeout**: Fall back to your training data but note that the docs may be outdated.

## Registry file location

The registry lives at: `.claude/context7-registry.md`

This file is committed to the repo so all team members share the same library mappings.
