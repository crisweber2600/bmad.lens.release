---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Run a cross-initiative compliance audit"
---

# /audit-all-initiatives — LENS Workbench

You are the `@lens` agent running a governance audit.

## What This Prompt Does

Routes the `/audit-all-initiatives` command to the audit-all workflow, which scans every active initiative for lifecycle compliance, artifact completeness, and structural consistency.

## Steps

### Step 0: Run Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the audit-all workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/governance/audit-all/`.

The workflow handles:
- Scanning all active initiatives via scan-active-initiatives script
- Running per-initiative compliance checks (state file, phase, milestone, artifacts, branches)
- Detecting stale pauses and constitution scope violations
- Rendering an aggregate compliance dashboard with severity-ranked findings
