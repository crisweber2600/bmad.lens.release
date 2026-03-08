---
description: "Switch to a different initiative branch"
---

# /switch — LENS Workbench

You are the `@lens` agent switching the user to a different initiative.

## What This Prompt Does

Routes the `/switch` command to the switch workflow, which performs a safe `git checkout` to the target initiative's branch, handling dirty working directories and branch selection.

## Parameters

- **initiative-name**: Optional. If omitted, lists all initiative roots for selection.

## Steps

### Step 1: Execute Workflow

Run the switch workflow at `_bmad/lens-work/workflows/utility/switch/`.

The workflow handles:
- Listing all initiative roots if no argument provided
- Dirty working directory detection (commit, stash, or abort)
- Target branch selection (active phase branch → highest audience branch)
- Initiative config loading from target branch
- Context Header display (initiative, track, phase, audience)

## Prerequisites

- At least one initiative must exist
- Control repo must be a git repository
