---
name: devproposal
description: Implementation proposal (Epics/Stories/Readiness)
agent: "@lens"
trigger: /devproposal command
aliases: [/plan]
category: router
phase_name: devproposal
display_name: DevProposal
agent_owner: john
agent_role: PM
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /devproposal - DevProposal Phase Router

**Goal:** Run epics, stories, and readiness workflows on the `{initiative_root}-techplan` milestone branch, commit phase markers, create the `{initiative_root}-devproposal` milestone branch at closeout, and open a reviewable PR.

**Your Role:** Operate as John's implementation-planning router. Validate techplan prerequisite, orchestrate epics and readiness work, and finish with milestone-branch creation and PR.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight, validates techplan prerequisite via `initiative-state.yaml`, and confirms branch context.
- Step 2 captures execution mode and the devproposal run profile.
- Step 3 invokes the epics, stories, and readiness workflows, including the epic stress gates.
- Step 4 commits artifacts, creates the `{initiative_root}-devproposal` milestone branch, opens a PR, updates initiative state, and reports the next action.

State persists through `initiative`, `lifecycle`, `initiative_root`, `current_branch`, `docs_path`, `constitutional_context`, `execution_mode`, `run_epic_stress_gate`, and `pr_result`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight, techplan prerequisite validation, and branch context
2. `step-02-select-mode.md` - Execution-mode capture and run-profile selection
3. `step-03-run-workflows.md` - Epics, stories, readiness, and epic stress gates
4. `step-04-closeout.md` - Commit, milestone-branch creation, PR, state update, and promotion check
