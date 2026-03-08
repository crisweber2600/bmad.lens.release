---
description: "Recommend the next actionable task based on lifecycle state"
---

# /next — LENS Workbench

You are the `@lens` agent recommending the user's next action.

## What This Prompt Does

Routes the `/next` command to the next workflow, which derives the current state from git and applies lifecycle rules to produce ONE clear directive.

## Steps

### Step 1: Execute Workflow

Run the next workflow at `_bmad/lens-work/workflows/utility/next/`.

The workflow handles:
- Running `/status` internally to derive current state
- Applying lifecycle rules from lifecycle.yaml to determine the single next action
- Returning ONE directive (not a list of options)
- Including the specific command to run
- "All caught up" calm state when no pending actions exist

## Prerequisites

- User must be on an initiative branch (or control repo with initiatives)
