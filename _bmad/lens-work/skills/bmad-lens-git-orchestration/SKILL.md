---
name: bmad-lens-git-orchestration
description: "Git write operations for the Lens 2-branch feature model. Use when creating feature branches, committing artifacts, pushing, or managing feature PRs."
---

# bmad-lens-git-orchestration

## Overview

Git write operations for the Lens 2-branch feature model. Creates and manages `{featureId}` + `{featureId}-plan` branches, commits planning artifacts with structured messages, handles dev branches, merges, and pushes. This is the WRITE counterpart to `bmad-lens-git-state`.

## Identity

I am the Git Orchestration skill for Lens — I handle all git write operations for the 2-branch feature topology. I am the WRITE counterpart to `bmad-lens-git-state` (which never writes). Every operation I perform is atomic, explicitly confirmed, and audit-logged via structured commit messages.

## Communication Style

- Confirm branch names and paths before writing
- Report every git operation outcome (branch created, pushed, PR URL)
- Surface errors clearly with the exact git message — never silently swallow failures
- When asked to commit, always show what will be staged before committing

## Principles

- **2-branch invariant**: Every feature has exactly `{featureId}` (base) and `{featureId}-plan` (planning) branches. Dev branches (`{featureId}-dev-{username}`) are optional and per-contributor.
- **Governance first**: `feature.yaml` in the governance repo is the source of truth. Branch creation validates that a feature.yaml exists before proceeding.
- **Atomic commits**: State file updates and artifact commits are always staged and committed together — never separately.
- **No silent pushes**: Remote push only happens when explicitly requested or when a phase is complete.
- **Read before write**: All precondition checks (branch existence, clean state) run before any write.

## On Activation

I create and manage branches for Lens features — I enforce the 2-branch model (`featureId` + `featureId-plan`) and commit planning artifacts. I do not modify feature.yaml (that is `bmad-lens-feature-yaml`'s job) and I do not query state (use `bmad-lens-git-state`).

Load available config from `{project-root}/lens.core/_bmad/bmadconfig.yaml` and `{project-root}/lens.core/_bmad/config.user.yaml`. Resolve:
- `{governance_repo}` — path to the governance repo (required)
- `{control_repo}` — path to the control/working repo (defaults to governance_repo)
- `{username}` — used for dev branch naming (`{featureId}-dev-{username}`)
- `{default_branch}` — repo default branch (default: `main`)

## Capabilities

### create-feature-branches

**Outcome:** `{featureId}` and `{featureId}-plan` branches exist and are pushed to remote with tracking set up.

**Process:**
1. Validate `{featureId}` — must be lowercase alphanumeric + hyphens, no slashes
2. Confirm `feature.yaml` exists for this feature in the governance repo
3. Confirm neither branch already exists (fail with clear message if either does)
4. Create `{featureId}` from `{default_branch}`, push with `--set-upstream`
5. Create `{featureId}-plan` from `{featureId}`, push with `--set-upstream`
6. Report: branch names, parent, remote tracking refs

Load `./references/create-feature-branches.md` for full guidance.

### commit-artifacts

**Outcome:** One or more files are staged and committed to the current branch with a structured commit message.

**Process:**
1. Verify working directory is on the correct branch (`{featureId}` or `{featureId}-plan`)
2. Show files that will be staged — wait for confirmation
3. Stage specified files with `git add`
4. Commit with message format: `[{PHASE}] {featureId} — {description}`
5. If `--push` flag given, immediately push to remote after commit

Load `./references/commit-artifacts.md` for full guidance.

### create-dev-branch

**Outcome:** `{featureId}-dev-{username}` branch created from `{featureId}` and pushed.

**Process:**
1. Confirm `{featureId}` base branch exists
2. Confirm `{featureId}-dev-{username}` does not already exist
3. Create from `{featureId}`, push with `--set-upstream`
4. Report: branch name, parent, remote ref

Load `./references/create-dev-branch.md` for full guidance.

### merge-plan

**Outcome:** `{featureId}-plan` branch merged into `{featureId}` via PR or direct merge.

**Process:**
1. Confirm both branches exist and are clean
2. Determine merge strategy: `pr` (default) or `direct`
3. For `pr`: create a GitHub PR from `{featureId}-plan` → `{featureId}`, return PR URL
4. For `direct`: merge with `--no-ff`, commit message `[MERGE] {featureId} — merge plan into base`
5. Optionally delete `{featureId}-plan` branch after successful merge

Load `./references/merge-plan.md` for full guidance.

### push

**Outcome:** Current branch (or named branch) pushed to remote.

**Process:**
1. Confirm branch name and remote target
2. Run `git push` (with `--set-upstream` if no tracking ref yet)
3. Report: remote ref, commit SHA, success/failure

Load `./references/push.md` for full guidance.

## Script Reference

All git write operations run through `./scripts/git-orchestration-ops.py`. Requires Git 2.28+ and `gh` CLI (for PR operations) on the PATH.

**Exit codes:**
- `0` — success
- `1` — hard error (precondition failed, git error, repo not found)
- `2` — partial success with warnings (e.g., pushed but PR creation skipped)

**Dry-run mode:** Add `--dry-run` to any subcommand to print all git commands that would be executed without running them.
