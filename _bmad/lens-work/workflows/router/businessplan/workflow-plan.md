# Workflow Plan: businessplan

## Goal

Launch the BusinessPlan phase on the small audience, run the selected planning workflows, and close the phase with a reviewable PR.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative and lifecycle context
   - Verify inherited artifacts and prepare the businessplan phase branch
2. `steps/step-02-select-workflows.md`
   - Capture interactive or batch execution mode
   - Select PRD, UX, and architecture work
3. `steps/step-03-run-workflows.md`
   - Invoke the selected planning sub-workflows in the correct order
4. `steps/step-04-closeout.md`
   - Commit artifacts, create the phase PR, update state, and surface `/techplan`

## Key State

- `initiative`
- `lifecycle`
- `phase_branch`
- `audience_branch`
- `docs_path`
- `constitutional_context`
- `execution_mode`
- `selected_workflows`
- `pr_result`

## Output Artifacts

- `prd.md`
- `ux-design.md` or `ux-design-specification.md`
- `architecture.md`
- Updated initiative state and businessplan phase PR