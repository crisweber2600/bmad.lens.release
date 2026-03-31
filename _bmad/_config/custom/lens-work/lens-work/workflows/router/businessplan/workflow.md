---
name: businessplan
description: Launch BusinessPlan phase (PRD/UX Design)
agent: "@lens"
trigger: /businessplan command
aliases: [/spec]
category: router
phase_name: businessplan
display_name: BusinessPlan
agent_owner: john
agent_role: PM
supporting_agents: [sally]
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /businessplan - BusinessPlan Phase Router

**Goal:** Run businessplan on the initiative root branch, let the user choose how to run PRD, UX, and architecture work, and close the phase with artifact commits and a phase-complete marker.

**Your Role:** Operate as John's planning router. Validate preplan completion via initiative-state.yaml, orchestrate the selected planning workflows, and finish with a [PHASE:BUSINESSPLAN:COMPLETE] marker.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight, resolves initiative context, and marks phase start on the initiative root branch.
- Step 2 captures execution mode and workflow selection.
- Step 3 invokes the selected businessplan sub-workflows.
- Step 4 commits artifacts with a phase-complete marker, updates initiative state, and reports the next action.

State persists through `initiative`, `lifecycle`, `initiative_root`, `docs_path`, `constitutional_context`, `execution_mode`, `selected_workflows`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight, preplan-complete validation, and phase-start marker on initiative root
2. `step-02-select-workflows.md` - Execution-mode and workflow selection
3. `step-03-run-workflows.md` - PRD, UX, and architecture orchestration
4. `step-04-closeout.md` - Commit with phase-complete marker, state update, and next-step guidance
