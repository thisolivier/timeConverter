# Agent Configuration

## Project Overview

**TimeConvertor** — a small universal macOS/iOS app (SwiftUI) for freeform timezone conversion. The user types a natural-language expression like "12pm ET in London" or "06:34 Portugal in PST" and the app parses it and shows the converted time. The core deliverables are: the universal app itself, a freeform input parser (spec to be defined in a dedicated session — backlog item 2), and a simple conversion UI with disambiguation prompts where the input is ambiguous.

Core tooling: Swift / SwiftUI, a single universal target for macOS and iOS, Xcode command-line builds. Dev-environment conventions are borrowed from the music-library iOS projects in `../iOSnative/` (read access only — never modify those repos).

## General Directives
- Keep code readable with verbose variable names — never abbreviate to a single letter
- Keep dependencies minimal (balance with low code directive)
- Prefer simple low-code solutions to complex ones where possible (balance with minimal dependency directive)
- When working on complex tasks, always use a todo list
- Use the `context7` skill proactively for library/API documentation — don't wait to be asked
- Use the `release-version` skill when preparing releases — follow semantic versioning conventions
- ALWAYS ask for permission before editing this file

Your work is deeply appreciated.

## Repository Layout

- `TimeConvertor/` — app source (SwiftUI views, parsing, conversion logic)
- `TimeConvertorTests/` — test suite
- `docs/` — backlog, specs (notably the input-parsing spec once written), and plans
- `scripts/` — build/run/test helper scripts

## Codebase Health
- Pro-actively modularize the code
  - Split groups of functions into separate files with clean interfaces
  - Prefer file lengths of less than 200 lines (light preference)
- Keep documentation up to date
  - Add readme.md files at the root of each module
  - Readme files should briefly describe module architecture and working patterns
  - Readme files should list the main components and their purposes
  - Ensure readme files are up to date at the end of each task
  - Readme files do not need to list every feature of the code, just the broad strokes
- Write tests for new features
- Run tests after every feature completion
- Ensure all tests can be run with a single command

## Paths Not to Modify
- Do not modify files managed by package managers.
- Never modify anything under `../iOSnative/` or other sibling project directories — read access only.
- ALWAYS ask for permission before editing this file
