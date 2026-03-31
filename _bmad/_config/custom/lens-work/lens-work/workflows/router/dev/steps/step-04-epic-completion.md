---
name: 'step-04-epic-completion'
description: 'Run epic-level review gates, create the epic PR, and stop until the epic merge completes'
nextStepFile: './step-05-closeout.md'
implementationReadinessWorkflow: '{project-root}/_bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md'
partyModeWorkflow: '{project-root}/_bmad/core/workflows/party-mode/workflow.md'
---

# Step 4: Epic Completion Gate

## STEP GOAL:

After all stories finish, run epic-level gates, create the epic PR into the initiative branch, and wait at the hard merge gate.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Treat the epic merge gate as a hard stop.
- Do not proceed to closeout until the epic PR is merged.

### Role Reinforcement:
- You are the LENS control-plane router.
- Protect the initiative branch from bypassing epic-level quality and review gates.

### Step-Specific Rules:
- Run the implementation-readiness gate before party mode.
- Create the epic PR only after all story PRs have been produced.
- Wait for the epic merge result instead of assuming success.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Use `{implementationReadinessWorkflow}` for the epic readiness gate and `{partyModeWorkflow}` for epic teardown.
- Persist `session.epic_branch`, `session.initiative_branch`, and `epic_pr_result` through the wait gate.

## CONTEXT BOUNDARIES:
- Available context: completed story state, `docs_path`, `constitutional_context`, `session.epic_branch`, and `session.initiative_branch`.
- Focus: epic-level review, PR creation, and merge confirmation.
- Limits: do not perform post-merge closeout in this step.
- Dependencies: all story work and story PR creation must already be complete.

---

## MANDATORY SEQUENCE

### 1. Epic Completion Gate (Mandatory)

Set `current_epic_id = epic-{session.epic_number}`.

Load and follow `{implementationReadinessWorkflow}` in epic scope, using the current stories document, implementation artifacts, and constitutional context. If the epic readiness result is blocked or failed, stop and require the user to resolve the findings before rerunning `/dev`.

Load and follow `{partyModeWorkflow}` against the current epic context. If party-mode teardown is not complete, stop and require the user to resolve the generated review artifact before rerunning `/dev`.

Commit and push the epic branch in the target repo, then create the epic PR from `session.epic_branch` into `session.initiative_branch`.

If PR creation falls back to manual instructions, surface the fallback and keep the recorded PR result. Otherwise display the created PR URL.

Wait up to 10 minutes for the epic PR to merge. If the PR is not merged in time, stop the workflow and instruct the user to merge the story PRs and epic PR before rerunning `/dev`.

When the merge completes, confirm that the epic has been integrated into the initiative branch and finish the epic-level workflow bookkeeping.

### 2. Auto-Proceed

Display: "**Proceeding to closeout...**"

#### Menu Handling Logic:
- After the epic PR merge gate completes successfully, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Halt only if epic readiness, party mode, PR creation, or the merge wait gate fails.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Epic readiness and party-mode teardown both pass.
- The epic branch is committed and pushed.
- The epic PR is created and merged into the initiative branch.

### SYSTEM FAILURE:
- Epic readiness review fails.
- Epic party-mode teardown fails.
- Epic PR cannot be created.
- The epic PR does not merge within the wait window.

**Master Rule:** Skipping steps is FORBIDDEN.