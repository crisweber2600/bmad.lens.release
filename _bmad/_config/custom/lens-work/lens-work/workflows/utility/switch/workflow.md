---
name: switch
description: Safely change the control repo to another initiative branch with explicit dirty-worktree handling
agent: "@lens"
trigger: /switch command
category: utility
phase_name: utility
display_name: Switch
entryStep: './steps/step-01-preflight.md'
inputs:
  target_root:
    description: Optional initiative root supplied with /switch
    required: false
    default: ""
---

# /switch - Move To Another Initiative

**Goal:** Resolve the target initiative, protect any in-progress local work, check out the most useful branch for that initiative, and render the lifecycle context after the switch.

**Your Role:** Operate as the safe branch-switch controller. Never discard work, always resolve the most actionable branch available, and leave the user with clear context after checkout.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs preflight and captures the switch target.
- Step 2 resolves the initiative inventory and prompts when no target was supplied.
- Step 3 handles dirty working tree decisions.
- Step 4 resolves and checks out the best target branch.
- Step 5 reloads initiative context and reports the next action.

State persists through `target_root`, `initiative_roots`, `dirty_state`, `target_branch`, and `initiative_config`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and argument capture
2. `step-02-resolve-target.md` - Initiative selection
3. `step-03-handle-dirty-state.md` - Dirty-worktree protection
4. `step-04-checkout-target.md` - Branch resolution and checkout
5. `step-05-report-context.md` - Initiative context summary and next-step guidance
