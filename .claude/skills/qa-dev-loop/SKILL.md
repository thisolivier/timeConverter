---
name: qa-dev-loop
description: Run a continuous QA, pain-point tracking, and development improvement loop on any application. Use when the user wants to iteratively test, document issues, fix bugs, and ship improvements in a structured cycle. Triggers on "QA loop", "pain points", "bug bash", "test and fix loop", "continuous improvement", "QA cycle".
---

# QA → Pain Points → Dev → Ship Loop

A structured, repeating cycle for improving application quality through hands-on testing, disciplined issue tracking, batched development, and verified shipping. Designed to be run by an autonomous agent with periodic user gates.

## When to use

- Application has working functionality that needs hardening
- User wants to find and fix real-world issues through actual usage
- User wants a structured process for continuous improvement without micromanaging each fix
- System needs QA across multiple features, edge cases, or integration points

## Core Cycle

```
┌─────────────────────────────────────────────────┐
│                                                 │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│   │   QA     │──▶│  TRIAGE  │──▶│   DEV    │   │
│   │  Phase   │   │  Phase   │   │  Phase   │   │
│   └──────────┘   └──────────┘   └──────────┘   │
│        ▲                             │          │
│        │         ┌──────────┐        │          │
│        └─────────│  SHIP    │◀───────┘          │
│                  │  Phase   │                   │
│                  └──────────┘                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

In testing, each rotation through the cycle typically takes 15–60 minutes depending on scope. The agent runs the loop autonomously but pauses at defined **user gates** (see Phase details).

## Pre-flight: Confirm Before Starting

**IMPORTANT:** Before entering the loop, the agent MUST ask the user for confirmation. Present a summary of what you understand about the project and ask these questions:

1. **Scope** — "Which features/workflows should I exercise during QA?" (List what you think is in scope based on the codebase and ask the user to confirm or adjust.)
2. **Pain points location** — "Where should I track issues?" (Propose a default like `docs/pain-points.md` and ask if that's correct.)
3. **Existing issues** — "Are there known issues I should verify first, or should I start fresh?"
4. **Successful output** — For pipeline/data-processing applications: "When the pipeline produces successful output, what should I do with it? (e.g., graduate it, leave it for manual review, archive it, move it somewhere specific)"
5. **Looping** — "Should I loop continuously until you tell me to stop, or pause after each round for your go-ahead?"

Do not begin the QA phase until the user has confirmed.

## Setup

Before starting the loop, establish:

1. **Pain points document** — a living markdown file where issues are tracked
2. **Archive directory** — completed rounds get archived here
3. **Thresholds** — when to switch from QA to Dev (default: 10 small / 3 medium / 1 large)
4. **Scope** — what features/workflows to exercise during QA

### Pain Points Document Format

```markdown
# Pain Points & Potential Improvements — Round N

Observations from [context]. Items marked **[fix]** have been addressed;
items marked **[todo]** are deferred for later.

Previous rounds archived at `[archive path]`.

## [Category Name]

### [todo] [S/M/L] Short description
Details about the issue, how it was discovered, and what the fix looks like.

### [fix] [S] Short description
What was fixed and how.
```

Severity key:
- **[S]** Small — cosmetic, minor UX, easy fix (< 30 min)
- **[M]** Medium — functional issue, moderate effort (30 min – 2 hours)
- **[L]** Large — architectural, breaking, or cross-cutting (> 2 hours, may need its own branch)

## Phase 1: QA Phase

**Goal:** Exercise the application like a real user. Find issues through actual usage, not just reading code.

### Instructions

1. **Vary your usage patterns.** Don't just repeat the happy path. Try:
   - Normal workflows end-to-end
   - Edge cases (empty inputs, duplicates, cancellation mid-flow)
   - Undo/redo operations (add then remove, create then delete)
   - Concurrent or overlapping operations
   - Recovery from errors (kill mid-operation, corrupt input)

2. **Document every issue immediately.** Add to the pain points document with:
   - Severity tag [S/M/L]
   - Category
   - How you discovered it
   - What the expected vs actual behavior was

3. **Verify previous fixes.** If this isn't the first round, re-test issues marked [fix] in the previous round to confirm they're truly resolved. Reopen if not.

4. **Use sub-agents for parallel QA** when testing independent features. Each sub-agent should add its own findings to the pain points doc.

### Exit criteria

Move to Triage when:
- You've exercised all in-scope features at least once, OR
- You've hit the pain point threshold (default: 10S / 3M / 1L), OR
- You've discovered a blocker (L severity) that must be fixed before further QA is meaningful

## Phase 2: Triage Phase

**Goal:** Prioritise the pain points and decide what to fix now vs defer.

### Instructions

1. **Review all [todo] items** in the pain points document
2. **Group by category** — look for clusters that share a root cause
3. **Identify quick wins** — [S] items that can be fixed in < 5 minutes alongside related work
4. **Identify blockers** — issues that prevent further QA or that make the application unreliable
5. **Draft a fix plan** — ordered list of what to fix this round

### User gate (optional)

If the user has asked for oversight on prioritisation, present the triage summary and ask which items to tackle. Otherwise, proceed autonomously using this priority order:
1. Blockers and data-integrity issues
2. Clusters (multiple symptoms, one root cause)
3. Quick wins that can piggyback on related fixes
4. Everything else by severity (L > M > S)

## Phase 3: Dev Phase

**Goal:** Fix the triaged issues. Write tests. Keep changes focused.

### Instructions

1. **Work through the fix plan sequentially** (or parallel via sub-agents for independent fixes)
2. **For each fix:**
   - Read the relevant code before changing it
   - Make the minimal change that addresses the issue
   - Write or update a test that would have caught the issue
   - Run the test suite after each fix
   - Mark the pain point as [fix] with a brief note on what changed
3. **Do not scope-creep.** If you notice a new issue while fixing something else, add it to the pain points doc as [todo] — don't fix it now unless it's blocking your current fix.
4. **Commit after each logical fix** (not one big commit at the end)

### Exit criteria

Move to Ship when:
- All planned fixes are implemented and tested, OR
- The dev phase is running long (testing shows ~45 minutes is a natural breakpoint) — ship what's ready, defer the rest

## Phase 4: Ship Phase

**Goal:** Verify everything works together and save progress.

### Instructions

1. **Run the full test suite.** All tests must pass.
2. **Smoke-test the application** — quick end-to-end exercise of the main workflow to verify no regressions.
3. **Archive the round** if all planned fixes are done:
   - Copy the pain points doc to the archive directory with a date prefix
   - Start a fresh pain points doc for the next round, carrying over any remaining [todo] items
4. **Update documentation** — READMEs, module docs, etc. if the fixes changed behavior or interfaces.

### User gate

Before starting the next QA round, check:
- Has the user given new scope or priorities?
- Should the agent pause and report progress?
- Are there any [L] items that need user input before proceeding?

If the user said "continue until further notice," proceed to the next QA phase. Otherwise, present a round summary and wait for instructions.

## Round Summary Template

At the end of each Ship phase, produce a brief summary:

```
## Round N Summary
- QA: [N] issues found ([S]x small, [M]x medium, [L]x large)
- Fixed: [N] issues
- Deferred: [N] issues (reasons)
- Tests: [pass/fail count]
- Key changes: [1-2 sentence summary]
- Next round focus: [what to exercise next]
```

## Special case: Data pipeline applications

When the application under test is a data pipeline (ETL, media processing, build system, etc.), QA produces real output as a side effect of exercising the system. This output has value — it shouldn't be silently discarded or left in limbo.

During **Pre-flight**, ask the user what to do with successful pipeline output. Common strategies:

- **Graduate it** — move output to its final destination (e.g., a media library, production database, output directory). This means QA doubles as real work.
- **Hold for manual review** — leave output in a staging area. The agent reports what's ready; the user decides when to promote it.
- **Discard after verification** — use output only to verify correctness, then clean up. Appropriate when QA is running against test data.

Whichever strategy the user picks, the agent should apply it consistently at the end of each QA phase (before Triage), and note any output-handling issues as pain points.

## Anti-patterns

- **Fixing while QA-ing.** Don't fix issues during the QA phase — just document them. Mixing QA and Dev leads to missed issues and half-done fixes.
- **Skipping the test.** Every fix needs a test. If you can't write a test, the fix isn't verifiable.
- **Gold-plating.** Don't refactor surrounding code, add features, or "improve" things that aren't broken. Fix what's on the list.
- **Ignoring small issues.** Small issues compound. A threshold of 10 small issues is still a trigger for a dev phase.
- **Endless QA without dev.** If you keep finding issues but never fix them, the pain points doc grows stale and the application doesn't improve. Respect the thresholds.
- **Endless dev without QA.** If you keep fixing but never re-test, you may introduce regressions. Ship and re-QA.

## Customisation Points

These defaults can be overridden when invoking the skill:

| Parameter | Default | Description |
|-----------|---------|-------------|
| Pain points file | `docs/pain-points.md` | Where to track issues |
| Archive directory | `docs/archive/` | Where to archive completed rounds |
| S threshold | 10 | Number of small issues before triggering dev |
| M threshold | 3 | Number of medium issues before triggering dev |
| L threshold | 1 | Number of large issues before triggering dev |
| Max dev time | 45 min | Time cap on a single dev phase |
| User gates | Triage + Ship | Which phases require user confirmation |
| Parallel QA | true | Whether to use sub-agents for QA |
