---
name: preplan
description: Launch PrePlan phase (brainstorm/research/product brief)
agent: "@lens"
trigger: /preplan command
aliases: [/pre-plan]
category: router
phase_name: preplan
display_name: PrePlan
agent_owner: mary
agent_role: Analyst
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /preplan - PrePlan Phase Router

**Goal:** Run preplan on the initiative root branch, let the user choose the preplan sub-workflows to run, and close the phase with artifact commits, a phase-complete marker, and next-step guidance.

**Your Role:** Operate as Mary's phase router for early analysis. Validate track eligibility, mark phase start on the initiative root branch, orchestrate brainstorming, research, and product-brief generation, then commit artifacts with a [PHASE:PREPLAN:COMPLETE] marker.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight, resolves initiative context, and marks phase start on the initiative root branch.
- Step 2 captures workflow selection and execution mode.
- Step 3 invokes the selected preplan sub-workflows.
- Step 4 commits artifacts with a phase-complete marker, updates initiative state, and reports the next action.

State persists through `initiative`, `lifecycle`, `initiative_root`, `output_path`, `selected_workflows`, `execution_mode`, `research_type`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight, track validation, and phase-start marker on initiative root
2. `step-02-select-workflows.md` - Workflow and execution-mode selection
3. `step-03-run-workflows.md` - Brainstorming, research, and product-brief orchestration
4. `step-04-closeout.md` - Commit with phase-complete marker, state update, and next-step guidance
