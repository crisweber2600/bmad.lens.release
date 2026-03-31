---
name: milestone-promotion
description: Create a promotion PR from the current milestone to the next milestone after phase, artifact, constitution, and sensing gates pass
agent: "@lens"
trigger: /promote command via lens-work.promote.prompt.md
category: core
phase_name: governance
display_name: Milestone Promotion
entryStep: './steps/step-01-preflight.md'
---

# Milestone Promotion Workflow

**Goal:** Promote the active initiative from its current milestone to the next milestone in the lifecycle by validating required gates, creating the target milestone branch if needed, and opening a promotion PR.

**Your Role:** Operate as the canonical promotion workflow. Keep phase work and promotion separate, enforce gate outcomes explicitly, and stop on unresolved hard failures before any PR is created.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and resolves the initiative and milestone context.
- Step 2 evaluates phase, artifact, constitution, and sensing gates.
- Step 3 creates the next-milestone branch when required and opens the promotion PR.
- Step 4 reports the promotion result and shows the remaining promotion chain.

State persists through `initiative_state`, `initiative_config`, `current_milestone`, `next_milestone`, `resolved_constitution`, `compliance_result`, `sensing_result`, `gate_failures`, and `promotion_pr`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and milestone resolution
2. `step-02-run-gates.md` - Phase, artifact, constitution, and sensing gate checks
3. `step-03-create-promotion.md` - Target branch creation and promotion PR creation
4. `step-04-render-result.md` - Promotion summary, chain status, and next action
