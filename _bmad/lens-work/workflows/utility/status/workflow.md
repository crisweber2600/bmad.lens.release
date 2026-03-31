---
name: status
description: Produce a consolidated initiative status report from git branch topology and provider PR state
agent: "@lens"
trigger: /status command
category: utility
phase_name: utility
display_name: Status
entryStep: './steps/step-01-preflight.md'
inputs:
  detail_initiative:
    description: Optional initiative root to expand in the detailed view
    required: false
    default: ""
---

# /status - Initiative Status Report Workflow

**Goal:** Summarize all active initiatives in a narrow-panel-friendly report, then expand into a detailed view when there is only one initiative or the user asks for one.

**Your Role:** Act as the control-plane status reporter. Derive all state from git and PR metadata, avoid stale shadow state, and return an operator-friendly summary of what is active and what should happen next.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Each step owns one reporting concern: preflight, inventory, state derivation, and rendering.
- State persists through `detail_initiative`, `current_branch`, `current_initiative_root`, `initiative_roots`, `status_rows`, `detail_rows`, and `empty_state`.
- Output defaults to a five-column summary table, with expanded detail only when the interaction justifies it.

---

## INITIALIZATION

### Configuration Loading

Load the lens-work session context already provided by `@lens` and resolve:

- `{user_name}`
- `{communication_language}`
- `{output_folder}`
- `{initiative_output_folder}`

### Workflow References

- `preflight_include = ../../includes/preflight.md`
- `lifecycle_contract = ../../../lifecycle.yaml`

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and reporting context initialization
2. `step-02-scan-initiatives.md` - Discover initiative roots and handle the empty state
3. `step-03-derive-state.md` - Derive audience, phase, PR state, and next action per initiative
4. `step-04-render-report.md` - Render the summary table and optional detailed view
