---
name: cleanup
description: Analyze and clean up orphaned worktrees and stale branches. Use when the user mentions stale branches, orphaned worktrees, cleanup, or wants to tidy up the git repository.
allowed-tools: Bash(git:*), Bash(gh:*)
---

# Cleanup

Analyze the repository for cleanup opportunities, then optionally execute with user approval.

## Step 1: Gather State

Run these commands to assess current state:

```bash
# Working trees
git worktree list

# All branches with age info
git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)|%(committerdate:relative)'

# Branches merged into main
git branch --merged main | grep -v '^\*' | grep -v 'main' | grep -v 'master'

# Local branches not tracking remote
git branch -vv --no-color | grep -v '\[origin/' | grep -v '^\*'

# Unstaged changes in current branch
git status --porcelain
```

Check GitHub for PR status:

```bash
gh pr list --state merged --json headRefName --limit 20 2>/dev/null || echo "gh unavailable"
gh pr list --state closed --json headRefName --limit 10 2>/dev/null || true
```

## Step 2: Categorize & Report

From the gathered data, categorize into two groups:

**Safe to remove (merged into main):**
- Branches from `git branch --merged main`
- Worktrees for those branches
- Orphaned worktree references

**Requires confirmation (not merged):**
- Worktrees for deleted branches
- Stale branches (30+ days) with closed PRs
- Branches not tracking any remote

Present a report:

```
## Cleanup Report

### Unstaged Changes
- [list any unstaged files from git status, or "None"]

### Orphaned Worktrees
- [path] - [reason]

### Branches Safe to Delete (merged)
- [branch] - merged [when]

### Stale Branches (30+ days, no open PR)
- [branch] - last commit [when]

### Branches with Closed/Merged PRs
- [branch] - PR #[n] [merged/closed]
```

## Step 3: Get Approval

Use AskUserQuestion with three options:
1. **Clean all** — remove safe + confirmed items
2. **Safe only** — remove only merged branches and prune worktrees
3. **Cancel** — keep everything as-is

## Step 4: Execute Cleanup

If the user chose cancel, stop here.

**Safe operations (no confirmation needed):**

```bash
git worktree prune
git branch -d <merged-branch>  # -d is safe, only deletes if merged
```

**Operations requiring confirmation (only if "Clean all" was chosen):**

For each unmerged branch the user approved:
```bash
git branch -D <branch>
```

For each worktree with potential changes:
```bash
git worktree remove <path> --force
```

## Step 5: Report Results

Show what was cleaned:

```
## Cleanup Complete

Removed:
- N branches deleted
- N worktrees removed

Skipped:
- [items user declined or that failed]
```

## Safety Rules

- Never delete the current branch
- Never delete main/master
- Use `git branch -d` (safe) for merged branches
- Use `git branch -D` (force) only with explicit user approval
- Always run `git worktree prune` before removing worktrees
