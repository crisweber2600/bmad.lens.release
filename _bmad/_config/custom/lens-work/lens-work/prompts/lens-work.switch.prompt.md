---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
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

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the switch workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/switch/`.

The workflow handles:
- Listing all initiative roots if no argument provided, including remote-tracking branches on `origin`
- Dirty working directory detection (commit, stash, or abort)
- Target branch selection (active phase branch → highest audience branch), resolving remote-only branches by creating a local tracking branch when needed
- Initiative config loading from target branch
- Context Header display (initiative, track, phase, audience)

## Prerequisites

- At least one initiative must exist
- Control repo must be a git repository
