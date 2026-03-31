---
name: compliance-check
description: Resolve constitution requirements and evaluate initiative artifacts against them
agent: "@lens"
trigger: Internal governance gate and on-demand compliance command
category: governance
phase_name: governance
display_name: Compliance Check
entryStep: './steps/step-01-preflight.md'
inputs:
	phase:
		description: Optional phase override for the compliance check
		required: false
		default: ""
	artifacts_path:
		description: Optional artifacts root override
		required: false
		default: ""
---

# Compliance Check Workflow

**Goal:** Resolve the effective constitution for the active initiative, evaluate artifact compliance for the requested phase, and return a PR-ready compliance summary.

**Your Role:** Operate as a governance gate wrapper. Keep the workflow read-only, use constitution skill contracts directly, and fail only when hard-gate requirements are unresolved.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and derives the initiative and phase context.
- Step 2 resolves the effective constitution.
- Step 3 evaluates compliance for the current phase and artifacts path.
- Step 4 renders the compliance summary and blocks on hard-gate failures.

State persists through `initiative_state`, `initiative_config`, `current_phase`, `artifacts_path`, `resolved_constitution`, and `compliance_result`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and initiative context
2. `step-02-resolve-constitution.md` - Resolve effective constitution
3. `step-03-run-compliance.md` - Execute constitutional compliance checks
4. `step-04-render-result.md` - Render summary and hard-gate failures
