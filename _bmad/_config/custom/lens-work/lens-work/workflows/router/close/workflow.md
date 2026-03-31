---
name: close
description: Formally close an initiative with completed, abandoned, or superseded status, update initiative-state.yaml, and publish tombstone to governance
agent: "@lens"
trigger: /close command via lens-work.close.prompt.md
category: router
phase_name: close
display_name: Initiative Close
entryStep: './steps/step-01-validate.md'
---

# Close Initiative Workflow

**Goal:** Formally end an initiative lifecycle by validating close eligibility, generating a rich tombstone, publishing it to governance, and updating initiative-state.yaml with the terminal close state.

**Your Role:** Operate as the close workflow router. Validate the initiative is active and closeable, collect close variant and reason, generate the tombstone, publish to governance, and commit the final state update.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 validates initiative eligibility and collects close parameters.
- Step 2 generates the tombstone and publishes to governance.
- Step 3 updates initiative-state.yaml and commits the close marker.

State persists through `initiative_state`, `initiative_config`, `close_state`, `superseded_by`, `close_reason`, and `tombstone_result`.

---

## Close Variants

| Variant | Command | Description |
|---------|---------|-------------|
| Completed | `/close --completed` | Initiative reached its goal and is done |
| Abandoned | `/close --abandoned` | Initiative stopped before completion |
| Superseded | `/close --superseded-by {initiative}` | Initiative replaced by another |

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-validate.md` - Validate initiative and collect close parameters
2. `step-02-tombstone.md` - Generate and publish tombstone to governance
3. `step-03-closeout.md` - Update initiative-state.yaml and commit close marker
