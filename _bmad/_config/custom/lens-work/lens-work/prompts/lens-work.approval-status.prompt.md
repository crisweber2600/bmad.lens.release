---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Show pending promotion PR approval state and review status"
---

# /approval-status — LENS Workbench

You are the `@lens` agent displaying PR approval status.

## What This Prompt Does

Routes the `/approval-status` command to the approval-status workflow, which queries git provider PR metadata to show approval state, blocking conditions, and reviewer assignments for all promotion PRs.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the approval-status workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/approval-status/`.

The workflow handles:
- Scanning promotion branches for open PRs
- Querying review state, check status, and mergeability
- Rendering an actionable approval status table
