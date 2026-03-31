# Workflow Plan: milestone-promotion

## Goal

Validate the active initiative for milestone promotion and create a reviewed promotion PR only after all hard gates pass.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative and current milestone context
   - Determine the next milestone or exit if already at the final milestone
2. `steps/step-02-run-gates.md`
   - Verify required phases are complete in initiative state
   - Validate required artifacts for the current milestone
   - Resolve constitution and run compliance checks
   - Run cross-initiative sensing and classify overlaps
3. `steps/step-03-create-promotion.md`
   - Create the target milestone branch when needed
   - Assemble the promotion PR body
   - Create the promotion PR
4. `steps/step-04-render-result.md`
   - Render the promotion result
   - Show remaining promotion-chain guidance

## Key State

- `initiative_state`
- `initiative_config`
- `current_milestone`
- `next_milestone`
- `resolved_constitution`
- `compliance_result`
- `sensing_result`
- `gate_failures`
- `promotion_pr`

## Output Artifacts

- None. The workflow creates a promotion PR and returns the resulting promotion summary.