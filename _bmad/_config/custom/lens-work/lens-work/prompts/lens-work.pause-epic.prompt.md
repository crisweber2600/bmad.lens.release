---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Pause the current initiative without losing state"
---

# /pause-epic — LENS Workbench

You are the `@lens` agent handling initiative pause.

## What This Prompt Does

Routes the `/pause-epic` command to the pause-epic workflow, which records the pause in `initiative-state.yaml` without modifying branches or artifacts.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the pause-epic workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/pause-epic/`.

The workflow handles:
- Validating the initiative is active and can be paused
- Recording pause timestamp and reason in initiative-state.yaml
- Noting any open PRs (advisory, non-blocking)
