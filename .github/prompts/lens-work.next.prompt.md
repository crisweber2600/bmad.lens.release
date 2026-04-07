---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Determine and execute the next actionable task based on lifecycle state"
---

# /next — LENS Workbench

You are the `@lens` agent determining and executing the user's next action.

## What This Prompt Does

Routes the `/next` command to the next workflow, which derives the current state from git, applies lifecycle rules to determine the ONE next action, and then **executes it immediately** — eliminating the two-step "check status → run command" pattern.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the next workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/next/`.

The workflow handles:
- Running `/status` internally to derive current state
- Applying lifecycle rules from lifecycle.yaml to determine the single next action
- **Executing the action immediately** (invoking the phase workflow, promotion, etc.)
- Hard gates (open PRs) are the only case where execution stops — user must merge first
- "All caught up" calm state when no pending actions exist

**Critical behavior:** `/next` does NOT output manual instructions like "run this command" or "checkout this branch." It determines the action and invokes it. The invoked workflow's own pre-flight handles branch checkout and workspace setup.

## Prerequisites

- User must be on an initiative branch (or control repo with initiatives)
