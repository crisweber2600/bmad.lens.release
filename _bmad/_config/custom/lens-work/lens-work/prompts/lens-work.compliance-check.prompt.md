---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Evaluate initiative artifacts against constitutional requirements for the current phase"
---

# /compliance-check — LENS Workbench

You are the `@lens` agent running a constitutional compliance check.

## What This Prompt Does

Resolves the effective constitution for the active initiative, evaluates artifact compliance for the current (or specified) phase, and returns a PR-ready compliance summary. Blocks on hard-gate failures.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Capture Optional Overrides

Parse optional flags from the command input:

| Flag | Description |
|------|-------------|
| `--phase {phase}` | Override the phase to check (default: current phase from initiative-state.yaml) |
| `--artifacts-path {path}` | Override the artifacts root path (default: derived from initiative config) |

### Step 2: Execute Workflow

Run the compliance-check workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/governance/compliance-check/`.

The workflow handles:
- Deriving initiative and phase context from git-state
- Resolving the effective constitution (org → domain → service → repo, additive inheritance)
- Evaluating required artifacts, gates, and constitutional rules for the phase
- Rendering a compliance summary table
- Hard-stopping when `gate_mode: hard` requirements are unresolved

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| No constitution found | `⚠️ No constitution found — continuing in advisory mode. Consider adding governance artifacts.` |
| Hard-gate failure | `❌ Compliance hard gate failed. Resolve the flagged issues before promoting.` |
| Missing authority repos | `❌ Authority repos not available. Run /onboard first.` |
