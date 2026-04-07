---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Formally close an initiative as completed, abandoned, or superseded"
---

# /close — LENS Workbench

You are the `@lens` agent closing an initiative.

## What This Prompt Does

Formally ends an initiative lifecycle by validating close eligibility, collecting the close variant and reason, generating a tombstone, publishing it to governance, and writing the terminal state to `initiative-state.yaml`.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Capture Close Variant

Parse optional flags from the command input:

| Flag | Close State | Description |
|------|-------------|-------------|
| `--completed` | `completed` | Initiative reached its goal |
| `--abandoned` | `abandoned` | Initiative stopped before completion |
| `--superseded-by {initiative}` | `superseded` | Initiative replaced by another |

If no flag is provided, prompt the user to choose a close variant before proceeding.

### Step 2: Execute Workflow

Run the close workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/router/close/`.

The workflow handles:
- Validating the initiative is active and eligible for closure
- Collecting the close reason from the user
- Generating a tombstone artifact and publishing it to governance
- Updating `initiative-state.yaml` with the terminal close state
- Committing the `[LENS:CLOSE]` marker commit

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Initiative already closed | `ℹ️ Initiative is already closed (state: {close_state}). No action needed.` |
| Dirty working directory | Defer to git-orchestration dirty handling (commit/stash/abort) |
| Missing authority repos | `❌ Authority repos not available. Run /onboard first.` |
