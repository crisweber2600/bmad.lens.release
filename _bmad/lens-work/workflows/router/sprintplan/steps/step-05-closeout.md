---
name: 'step-05-closeout'
description: 'Commit phase marker, create the sprintplan milestone branch, open PR, update state, log events, and hand off to development'
promotionCheckInclude: '../../includes/promotion-check.md'
---

# Step 5: Closeout, State, And Handoff

## STEP GOAL:

Finish SprintPlan by committing the phase complete marker, creating the `{initiative_root}-sprintplan` milestone branch, opening a PR, updating initiative state, logging events, and handing off the selected story to development.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Never auto-merge the SprintPlan PR.
- Persist state and event-log updates before handoff is announced.

### Role Reinforcement:
- You are the LENS control-plane router.
- Finish SprintPlan with auditable milestone branch state, reviewable PR, and a clean handoff into `/dev`.

### Step-Specific Rules:
- Use `git-orchestration.create-milestone-branch` to create the milestone branch.
- Run `{promotionCheckInclude}` after state and handoff updates complete.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Persist `pr_result`, `gate_status`, `compliance_warnings`, `missing`, and event-log entries before announcing completion.

## CONTEXT BOUNDARIES:
- Available context: `current_branch`, `initiative_root`, `missing`, `compliance_warnings`, `readiness`, `story_id`, and `{promotionCheckInclude}`.
- Focus: phase marker, milestone branch creation, PR, state updates, event logging, and development handoff.
- Limits: do not rerun readiness or story generation in this step.
- Dependencies: successful sprint planning and dev-story generation.

---

## MANDATORY SEQUENCE

### 1. Phase Complete Marker

Commit the phase complete marker on the current branch:

```yaml
invoke: git-orchestration.update-phase-complete
params:
  initiative_id: ${initiative.id || initiative_root}
  phase: "sprintplan"
  branch: ${current_branch}
  commit_message: |
    [PHASE:SPRINTPLAN:COMPLETE] SprintPlan artifacts finalized
    Artifacts: sprint-backlog.md, dev-story files
  artifacts:
    - sprint-backlog.md
    - dev-story files
```

### 2. Create Milestone Branch And PR

Create the sprintplan milestone branch from the current branch state and push it:

```yaml
sprintplan_branch = "${initiative_root}-sprintplan"

invoke: git-orchestration.create-milestone-branch
params:
  milestone: "sprintplan"
  initiative_root: ${initiative_root}
  source_branch: ${current_branch}
  new_branch: ${sprintplan_branch}

invoke: git-orchestration.push
params:
  branch: ${sprintplan_branch}

compliance_status = invoke: lens-work.compliance-check
params:
  phase: "sprintplan"
  artifacts_path: ${docs_path}

sensing_report = invoke: lens-work.sensing
params:
  initiative_root: ${initiative_root}

pr_result = invoke: git-orchestration.create-pr
params:
  source_branch: ${sprintplan_branch}
  target_branch: main
  title: "[MILESTONE] ${initiative.id || initiative.initiative_root} - SprintPlan complete"
  body: |
    SprintPlan milestone for ${initiative.initiative_root}.
    Constitution compliance: ${compliance_status}
    Sensing report: ${sensing_report}
    Review sprint backlog and dev-story artifacts before merging.
```

### 3. Gate Updates - Mark Pass Or Block

Compute `gate_status = passed_with_warnings` when artifact warnings or compliance warnings remain; otherwise use `passed`.

Update initiative state for the sprintplan milestone:

```yaml
invoke: git-orchestration.update-milestone-promote
params:
  initiative_id: ${initiative.id || initiative_root}
  milestone: "sprintplan"
  phase: "sprintplan"
  phase_status: "complete"
```

### 4. Event Logging

Append the SprintPlan start, checklist, compliance, and completion events to the event log.

### 5. Commit State Changes

Commit and push the updated initiative state, event log, SprintPlan outputs, and docs changes on the sprintplan milestone branch.

### 6. Hand Off To Developer

Display the development handoff summary with the selected story, assignee, sprintplan milestone branch, PR result, and next-step instructions.

Ask the user to confirm the developer handoff. If the user declines, stop after showing the handoff summary so they can review the branch and PR state manually.

### 7. Check Promotion Readiness

Load and apply `{promotionCheckInclude}` so LENS can determine whether the initiative is ready to promote beyond SprintPlan.


## OUTPUT ARTIFACTS

| Artifact | Location |
|----------|----------|
| Dev Story | `${initiative.docs.bmad_docs}/dev-story-${id}.md` |
| Sprint Backlog | `${initiative.docs.bmad_docs}/sprint-backlog.md` |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` |
| Event Log | `_bmad-output/lens-work/event-log.jsonl` |


## ERROR HANDLING

| Error | Recovery |
|-------|----------|
| DevProposal not complete | Error: run `/devproposal` first |
| Missing artifacts | Warn with list, offer override (passed_with_warnings) |
| Readiness blockers | Block - must resolve before proceeding |
| Dirty working directory | Prompt to stash or commit changes first |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |
| PR link generation failed | Output manual PR instructions |
| Sprint planning failed | Allow manual story selection |


## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- `[PHASE:SPRINTPLAN:COMPLETE]` marker is committed.
- `{initiative_root}-sprintplan` milestone branch is created with a reviewable PR.
- Initiative state, workflow state, and event logs are updated and committed.
- The dev-story handoff is presented and promotion readiness is checked.

### SYSTEM FAILURE:
- Milestone branch creation fails.
- PR creation fails without a usable fallback.
- State updates or event logging fail.
- Required SprintPlan outputs cannot be committed.

**Master Rule:** Skipping steps is FORBIDDEN.