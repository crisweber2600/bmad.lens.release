---
name: sprintplan
description: Sprint planning phase - sprint-status, story files, dev handoff
agent: "@lens"
trigger: /sprintplan command
aliases: [/review, /sprint]
category: router
phase_name: sprintplan
display_name: SprintPlan
agent_owner: bob
agent_role: Scrum Master
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /sprintplan - SprintPlan Phase Router

**Goal:** Validate readiness on the `{initiative_root}-devproposal` milestone branch, run sprint planning, create dev-ready stories, commit phase markers, create the `{initiative_root}-sprintplan` milestone branch at closeout, and hand off to developers.

**Your Role:** Route the SprintPlan phase as Bob's control-plane workflow, enforcing devproposal prerequisite, readiness checks, and constitutional compliance before any developer handoff occurs.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Each step keeps a single concern in focus so phase routing remains maintainable.
- State persists through the active initiative context: `initiative`, `initiative_root`, `docs_path`, `bmad_docs`, `current_branch`, `constitutional_context`, `missing`, `compliance_warnings`, `compliance_checked`, `readiness`, `selected_story`, `story_id`, `story_title`, `developer_name`, `pr_result`, and `gate_status`.
- The execution order matches the legacy router exactly; only the structure changed.

---

## INITIALIZATION

### Configuration Loading

Load the lens-work session context already provided by `@lens` and resolve:

- `{user_name}`
- `{communication_language}`
- `{output_folder}`
- `{initiative_output_folder}`
- `{personal_output_folder}`

### Workflow References

- `module_config = ../../../bmadconfig.yaml`
- `lifecycle_contract = ../../../lifecycle.yaml`
- `preflight_include = ../../includes/preflight.md`
- `promotion_check_include = ../../includes/promotion-check.md`

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Pre-flight, devproposal prerequisite validation, artifact gate
2. `step-02-readiness.md` - Constitutional context, readiness validation, compliance gate
3. `step-03-sprint-planning.md` - Sprint planning sub-workflow execution
4. `step-04-dev-story.md` - Dev-ready story creation
5. `step-05-closeout.md` - Milestone-branch creation, PR, state updates, event log, developer handoff, promotion check
