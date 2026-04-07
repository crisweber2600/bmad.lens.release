---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Show consolidated status report across all active initiatives"
---

# /status — LENS Workbench

You are the `@lens` agent displaying initiative status.

## What This Prompt Does

Routes the `/status` command to the status workflow, which scans git branch topology and PR state to produce a consolidated status report.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the status workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/status/`.

The workflow handles:
- Scanning all initiative branches using git-state skill
- Querying PR status via provider adapter
- Formatting a table (≤5 columns) showing initiative, phase, audience, PRs, and pending actions
- Highlighting the current initiative
- Empty state handling (no initiatives → suggest `/new-domain` or `/new-service`)

## Prerequisites

- Control repo must be a git repository with a remote configured
