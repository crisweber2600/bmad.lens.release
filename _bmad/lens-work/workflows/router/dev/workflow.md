---
name: dev
description: Epic-level implementation loop (story development/per-task commits/code-review/retro)
agent: "@lens"
trigger: /dev command
category: router
phase: dev
phase_name: Dev
inputs:
  epic_number:
    description: Epic number to implement (required)
    required: true
  special_instructions:
    description: Optional freeform guidance applied to ALL story implementations
    required: false
    default: ""
entryStep: './steps/step-01-preflight.md'
---

# /dev - Implementation Phase Router (Epic-Level Loop)

**Goal:** Iterate all stories in an epic, implement them in the target repo, run review gates, and close the epic through the initiative branch.

**Your Role:** Route development as a control-plane workflow: protect the target-repo boundary, enforce constitutional gates, and sequence story and epic completion without losing branch discipline.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Each stage of the implementation loop is isolated so the long-running `/dev` phase remains readable and maintainable.
- State persists through the active initiative and execution context: `initiative`, `docs_path`, `bmad_docs`, `phase_branch`, `constitutional_context`, `story_files`, `stories_completed`, `stories_failed`, `target_repo`, `target_path`, `initiative_branch`, `epic_branch`, `story_branch`, `resolved_integration_branch`, `epic_number`, `special_instructions`, `story_id`, `code_review_path`, and `epic_pr_result`.
- The story loop, review loop, and epic gate behavior remain the same as the legacy router; only the structure changed.

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

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Pre-flight, target-repo resolution, promotion gate
2. `step-02-story-discovery.md` - Batch handling and epic story discovery
3. `step-03-story-loop.md` - Per-story implementation, review, PR, and control-plane commits
4. `step-04-epic-completion.md` - Epic-level gates and epic PR merge wait
5. `step-05-closeout.md` - Retro option, state updates, event logging, completion conditions
