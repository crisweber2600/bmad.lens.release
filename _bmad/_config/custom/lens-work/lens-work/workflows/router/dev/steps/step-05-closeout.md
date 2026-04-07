---
name: 'step-05-closeout'
description: 'Run the optional retrospective, persist dev state, and finalize initiative completion when applicable'
workflowXml: '{project-root}/lens.core/_bmad/core/tasks/workflow.yaml'
retrospectiveWorkflow: '{project-root}/lens.core/_bmad/bmm/workflows/4-implementation/retrospective/workflow.yaml'
---

# Step 5: Closeout And Initiative State

## STEP GOAL:

Offer the retrospective, persist dev state, append the event log, and complete the initiative when all phases are done.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Persist control-plane state before declaring `/dev` complete.
- Keep implementation writes in the TargetProject repo and state writes in `_bmad-output/`.

### Role Reinforcement:
- You are the LENS control-plane router.
- Close the implementation phase without losing auditability, branch discipline, or initiative state.

### Step-Specific Rules:
- The retrospective remains optional.
- State updates, event logging, and control-plane commits are mandatory.
- Only mark the initiative complete when all phases are actually complete.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Use `{workflowXml}` to execute `{retrospectiveWorkflow}` when the user opts into a retrospective.
- Persist phase status, event log, and control-plane commits before evaluating initiative completion.

## CONTEXT BOUNDARIES:
- Available context: `initiative`, `story_id`, `constitutional_context`, `session.target_path`, and `_bmad-output` state artifacts.
- Focus: retrospective decision, state persistence, event logging, and initiative closeout.
- Limits: do not restart story or epic execution from this step.
- Dependencies: successful epic merge gate.

---

## MANDATORY SEQUENCE

### 1. Retrospective (Optional)

Ask whether to run the retrospective.

If the user accepts:
- start workflow tracking for the retrospective
- load `{workflowXml}`
- execute `{retrospectiveWorkflow}` with the current constitutional context
- finish workflow tracking after the retrospective completes

### 2. Update State Files And Initiative Config

Update the initiative record and workflow state so `/dev` remains the active phase, the large-to-base gate is marked passed, and the current story context is preserved in the control-plane state.

### 3. Commit State Changes

Commit and push the updated initiative state, event log, and implementation artifacts on the `/dev` phase branch.

### 4. Log Event

Append the `/dev` event-log entry that records initiative id, phase, workflow, story id, and in-progress status.

### 5. Complete Initiative (When All Done)

If all phases are complete:
- update the initiative status to `complete`
- archive initiative state through `state-management.archive`
- commit and push the final `_bmad-output/lens-work/` state
- display the initiative completion summary


## CONTROL-PLANE RULE REMINDER

Throughout `/dev`, the user may work in TargetProjects for actual coding, but all lens-work commands continue to execute from the BMAD directory:

| Action | Location | Note |
|--------|----------|------|
| Write code / create files | TargetProjects/${repo} (session.target_path) | **ONLY here** |
| Run /dev commands | BMAD directory | Control plane |
| Read framework files | {release_repo_root}/ | **READ-ONLY - never write here** |
| State tracking writes | _bmad-output/ | Sprint status, initiative config |
| Code review | BMAD directory | |
| Status checks | BMAD directory | |

**⚠️ {release_repo_root} is NEVER the implementation target.** It is a read-only authority repo containing BMAD framework code.


## OUTPUT ARTIFACTS

| Artifact | Location |
|----------|----------|
| Code Review Report | `_bmad-output/implementation-artifacts/code-review-${id}.md` |
| Party Mode Review Report | `_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md` |
| Epic Party Mode Review Report | `_bmad-output/implementation-artifacts/epic-*-party-mode-review.md` |
| Complexity Tracking | `{bmad_docs}/complexity-tracking.md` |
| Retro Notes | `_bmad-output/implementation-artifacts/retro-${id}.md` |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` |
| Event Log | `_bmad-output/lens-work/event-log.jsonl` |


## ERROR HANDLING

| Error | Recovery |
|-------|----------|
| No dev story | Prompt to run /sprintplan first |
| SprintPlan not merged | Error with merge gate blocked message |
| Constitution gate not passed | Auto-triggers audience promotion (large -> base) |
| Audience promotion failed | Error - must complete large -> base promotion |
| Dirty working directory | Prompt to stash or commit changes first |
| Target repo checkout failed | Check target_repos config, retry |
| Branch creation failed | Check remote connectivity, retry with backoff |
| Dev story compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Article-specific gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Pre-implementation gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Checklist quality gate failed | Complete checklist items or override with justification |
| Code review failed | Allow retry or manual review |
| Code review compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Post-review re-validation failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Party mode teardown failed | Address party-mode findings and re-run code review |
| Epic adversarial review failed | Resolve implementation-readiness findings for the epic and re-run code review |
| Epic party mode teardown failed | Address epic party-mode findings and re-run code review |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |


## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Optional retrospective handling is complete.
- Initiative state, workflow state, and event log are persisted.
- Control-plane changes are committed and pushed.
- The initiative is marked complete and archived when all phases are done.

### SYSTEM FAILURE:
- Retrospective execution fails after the user opts in.
- State files cannot be updated or committed.
- Event logging or initiative archiving fails.

**Master Rule:** Skipping steps is FORBIDDEN.