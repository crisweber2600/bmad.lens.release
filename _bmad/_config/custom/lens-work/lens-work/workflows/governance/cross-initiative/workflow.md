---
name: cross-initiative
description: Run cross-initiative sensing and classify overlaps under the current constitutional gate mode
agent: "@lens"
trigger: /sense command and internal promotion checks
category: governance
phase_name: governance
display_name: Cross-Initiative Sensing
entryStep: './steps/step-01-preflight.md'
inputs:
   enforce_gate:
      description: When true, fail if a hard sensing gate finds overlaps
      required: false
      default: false
---

# Cross-Initiative Sensing Workflow

**Goal:** Detect overlapping initiatives using git-derived branch topology, classify the result under the effective sensing gate mode, and return a report that promotion or on-demand callers can consume.

**Your Role:** Operate as a read-only sensing wrapper. Use the sensing skill for topology analysis, the constitution skill for gate mode, and keep any blocking decision explicit.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and resolves the initiative context.
- Step 2 runs the sensing scan.
- Step 3 resolves the constitutional sensing gate mode.
- Step 4 renders the result and optionally fails when hard-gate enforcement is requested.

State persists through `initiative_state`, `initiative_config`, `sensing_report`, `resolved_constitution`, and `sensing_result`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and initiative context
2. `step-02-run-sensing.md` - Run the sensing scan
3. `step-03-resolve-gate.md` - Resolve sensing gate mode from constitution
4. `step-04-render-result.md` - Render the result and enforce hard gate when requested
