---
validationStatus: COMPLETE
validationDate: 2026-03-23
validationReport: './validation-report-2026-03-23.md'
---

# Workflow Plan: sprintplan

## Goal

Validate SprintPlan readiness, run sprint planning, create the selected dev-ready story, and close the phase with a PR and developer handoff.

## Step Structure

1. `steps/step-01-preflight.md`
   - Resolve initiative context from git
   - Enforce medium-to-large promotion
   - Prepare the SprintPlan branch
   - Check required artifacts
2. `steps/step-02-readiness.md`
   - Resolve constitutional context
   - Re-run readiness checks
   - Block on compliance failures
3. `steps/step-03-sprint-planning.md`
   - Run the Scrum Master sprint-planning sub-workflow
   - Produce sprint backlog output
4. `steps/step-04-dev-story.md`
   - Create the dev-ready story artifact for the selected story
5. `steps/step-05-closeout.md`
   - Push and create the SprintPlan PR
   - Update state and event log
   - Hand off to development and check promotion readiness

## Key State

- `initiative`
- `initiative_root`
- `docs_path`
- `bmad_docs`
- `phase_branch`
- `constitutional_context`
- `missing`
- `compliance_warnings`
- `readiness`
- `selected_story`
- `story_id`
- `story_title`
- `developer_name`
- `pr_result`
- `gate_status`

## Output Artifacts

- `${initiative.docs.bmad_docs}/sprint-backlog.md`
- `${initiative.docs.bmad_docs}/dev-story-${id}.md`
- `_bmad-output/lens-work/initiatives/${id}.yaml`
- `_bmad-output/lens-work/event-log.jsonl`