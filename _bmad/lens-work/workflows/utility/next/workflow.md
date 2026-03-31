---
name: next
description: Determine the single next lifecycle action and execute it when no hard gate blocks progress
agent: "@lens"
trigger: /next command
category: utility
phase_name: utility
display_name: Next
entryStep: './steps/step-01-preflight.md'
---

# /next - Execute The Recommended Next Action

**Goal:** Derive the current lifecycle state from the status workflow, apply the lifecycle decision rules in order, and either execute the next command immediately or surface the blocking gate.

**Your Role:** Operate as the lifecycle dispatcher. Use git-derived state and lifecycle.yaml to collapse multiple possible next steps into one deterministic action, then hand off cleanly to the owning workflow.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and gathers the status snapshot.
- Step 2 evaluates lifecycle rules and decides whether execution, gating, or terminal messaging applies.
- Step 3 renders the context header and either invokes the next command or stops on a hard gate.

State persists through `status_snapshot`, `current_row`, `next_command`, `gate_message`, and `execution_mode`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and status snapshot capture
2. `step-02-derive-action.md` - Lifecycle rule evaluation and action selection
3. `step-03-execute-or-report.md` - Context header, execution handoff, or hard-gate response
