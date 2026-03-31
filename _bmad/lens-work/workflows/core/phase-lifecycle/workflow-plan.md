# Workflow Plan: phase-lifecycle

## Goal

Close a completed phase safely by validating its artifacts, creating the phase PR, checking promotion readiness, and cleaning up merged phase branches.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Load initiative and lifecycle context
   - Resolve source and target branches
2. `steps/step-02-validate-completion.md`
   - Determine the required artifacts for the phase
   - Block if any required artifact is missing or empty
3. `steps/step-03-create-phase-pr.md`
   - Generate the phase PR title and artifact checklist body
   - Create the PR idempotently and emit the next-step guidance
   - Check whether promotion readiness should be surfaced
4. `steps/step-04-cleanup.md`
   - Verify whether the phase PR is merged
   - Delete stale merged phase branches only when it is safe
   - Close with the lifecycle result summary and next-command guidance

## Key State

- `phase_name`
- `display_name`
- `initiative_id`
- `initiative`
- `lifecycle`
- `required_artifacts`
- `missing_artifacts`
- `phase_branch`
- `audience_branch`
- `pr_title`
- `pr_body`
- `pr_result`
- `promotion_ready`

## Output Artifacts

- Provider PR for the completed phase
- Optional cleanup of merged phase branches