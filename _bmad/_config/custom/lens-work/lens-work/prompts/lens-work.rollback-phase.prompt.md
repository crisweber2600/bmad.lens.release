---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Roll back to a previous lifecycle phase"
---

# /rollback-phase — LENS Workbench

You are the `@lens` agent handling phase rollback.

## What This Prompt Does

Routes the `/rollback-phase` command to the rollback-phase workflow, which safely reverts `initiative-state.yaml` to a previous phase while preserving all git history and artifacts.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the rollback-phase workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/rollback-phase/`.

The workflow handles:
- Validating rollback eligibility (not at first phase, no open PRs)
- Presenting rollback options and getting user confirmation
- Updating initiative-state.yaml to the target phase
- Committing the change with a descriptive message
