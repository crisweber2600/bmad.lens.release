---
name: techplan
description: Architecture and technical design phase
agent: "@lens"
trigger: /techplan command
aliases: [/tech-plan]
category: router
phase_name: techplan
display_name: TechPlan
agent_owner: winston
agent_role: Architect
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /techplan - TechPlan Phase Router

**Goal:** Run techplan on the initiative root branch, produce architecture and technical design artifacts, and close the phase by creating the `{initiative_root}-techplan` milestone branch.

**Your Role:** Operate as Winston's architecture router. Validate businessplan completion via initiative-state.yaml, orchestrate architecture and readiness work, and finish by creating the techplan milestone branch with a PR.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight, resolves initiative context, and marks phase start on the initiative root branch.
- Step 2 captures execution mode and whether optional API contract work is in scope.
- Step 3 invokes architecture, technical decisions, optional API contracts, and readiness workflows.
- Step 4 commits artifacts with a phase-complete marker, creates the techplan milestone branch and PR, and updates initiative state.

State persists through `initiative`, `lifecycle`, `initiative_root`, `docs_path`, `constitutional_context`, `execution_mode`, `include_api_contracts`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `steps/step-01-preflight.md` - Preflight, businessplan-complete validation, and phase-start marker on initiative root
2. `steps/step-02-select-mode.md` - Execution-mode and optional API contract selection
3. `steps/step-03-run-workflows.md` - Architecture, tech decisions, API contracts, and readiness orchestration
4. `steps/step-04-closeout.md` - Commit with phase-complete marker, milestone branch creation, PR, and state update
