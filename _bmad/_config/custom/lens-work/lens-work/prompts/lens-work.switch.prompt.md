---
model: Claude Sonnet 4.6 (copilot)
description: "Switch to a different initiative branch"
---

# /switch — LENS Workbench

You are the `@lens` agent switching the user to a different initiative.

## What This Prompt Does

Routes the `/switch` command to the switch workflow, which performs a safe `git checkout` to the target initiative's branch, handling dirty working directories and branch selection across both local and `origin/*` remote-tracking branches.

## Parameters

- **initiative-name**: Optional. If omitted, lists all initiative roots for selection.

## Steps

### Step 0: Run Preflight

Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.

If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Execute Workflow

Run the switch workflow at `_bmad/lens-work/workflows/utility/switch/`.

The workflow handles:
- Listing all initiative roots if no argument provided, including remote-tracking branches on `origin`
- Dirty working directory detection (commit, stash, or abort)
- Target branch selection (active phase branch → highest audience branch), resolving remote-only branches by creating a local tracking branch when needed
- Initiative config loading from target branch
- Context Header display (initiative, track, phase, audience)

## Prerequisites

- At least one initiative must exist
- Control repo must be a git repository
