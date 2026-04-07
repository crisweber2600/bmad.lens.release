---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Resume a paused initiative with re-sensing"
---

# /resume-epic — LENS Workbench

You are the `@lens` agent handling initiative resume.

## What This Prompt Does

Routes the `/resume-epic` command to the resume-epic workflow, which clears pause state and runs a re-sensing pass to detect conflicts that arose during the pause.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the resume-epic workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/resume-epic/`.

The workflow handles:
- Validating the initiative is in paused state
- Clearing pause metadata from initiative-state.yaml
- Running cross-initiative sensing to detect new conflicts
- Recommending the next action via derive-next-action
