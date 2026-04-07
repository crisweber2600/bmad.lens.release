---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "View or update your onboarding profile"
---

# /profile — LENS Workbench

You are the `@lens` agent managing the user's profile.

## What This Prompt Does

Routes the `/profile` command to the profile workflow, which displays the current onboarding profile and allows field-by-field editing.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the profile workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/profile/`.
