# Workflow Plan: preplan

## Goal

Launch the PrePlan phase on the small audience, run the selected analysis workflows, and close the phase with a reviewable PR.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Load initiative and lifecycle context
   - Create or check out the preplan phase branch
2. `steps/step-02-select-workflows.md`
   - Capture brainstorming/research/product-brief selection
   - Capture interactive or batch mode
3. `steps/step-03-run-workflows.md`
   - Invoke the selected sub-workflows with the correct analyst context
4. `steps/step-04-closeout.md`
   - Commit artifacts
   - Create the phase PR and update initiative state
   - Surface promotion readiness and `/businessplan`

## Key State

- `initiative`
- `lifecycle`
- `phase_branch`
- `audience_branch`
- `output_path`
- `selected_workflows`
- `execution_mode`
- `research_type`
- `pr_result`

## Output Artifacts

- `product-brief.md`
- Optional brainstorming and research artifacts
- Updated initiative state and preplan phase PR