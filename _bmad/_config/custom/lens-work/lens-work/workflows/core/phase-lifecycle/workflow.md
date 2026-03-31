---
name: phase-lifecycle
description: Manage phase completion checks, automatic phase PR creation, promotion readiness, and safe branch cleanup
agent: "@lens"
trigger: internal phase completion workflow
category: core
phase_name: core
display_name: Phase Lifecycle
entryStep: './steps/step-01-preflight.md'
inputs:
   phase_name:
      description: Current phase being completed
      required: true
   display_name:
      description: Human-readable phase display name
      required: true
   initiative_id:
      description: Initiative identifier for the active phase
      required: true
---

# Phase Lifecycle Workflow

**Goal:** Detect whether a phase is complete, create or report the phase PR, surface promotion readiness, and clean up merged phase branches without losing execution state.

**Your Role:** Operate as the phase-closeout controller. Validate artifacts before any PR is created, derive state from lifecycle and git metadata, and keep cleanup safe by verifying merge state before deleting branches.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Each step handles one lifecycle concern: preflight, completion validation, PR creation, and cleanup.
- State persists through `phase_name`, `display_name`, `initiative_id`, `initiative`, `lifecycle`, `required_artifacts`, `missing_artifacts`, `phase_branch`, `audience_branch`, `pr_title`, `pr_body`, `pr_result`, and `promotion_ready`.
- This workflow is invoked by phase routers after artifact production; it does not replace the routers' branch start logic.

---

## INITIALIZATION

### Configuration Loading

Load the lens-work session context already provided by `@lens` and resolve:

- `{user_name}`
- `{communication_language}`
- `{output_folder}`
- `{initiative_output_folder}`

### Workflow References

- `preflight_include = ../../includes/preflight.md`
- `promotion_check_include = ../../includes/promotion-check.md`
- `lifecycle_contract = ../../../lifecycle.yaml`

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and lifecycle context initialization
2. `step-02-validate-completion.md` - Required artifact validation and gate enforcement
3. `step-03-create-phase-pr.md` - Phase PR body generation, PR creation, and promotion-readiness signaling
4. `step-04-cleanup.md` - Safe merged-branch cleanup and final response
