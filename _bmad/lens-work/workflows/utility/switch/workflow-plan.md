# Workflow Plan: switch

## Goal

Safely switch the control repo to another initiative branch without losing local work or landing on an unhelpful branch.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Capture the optional initiative target
2. `steps/step-02-resolve-target.md`
   - Discover initiative roots
   - Prompt for selection when no target was supplied
3. `steps/step-03-handle-dirty-state.md`
   - Detect uncommitted work
   - Offer commit, stash, or abort
4. `steps/step-04-checkout-target.md`
   - Resolve the best branch for the target initiative
   - Check out the branch locally or from origin
5. `steps/step-05-report-context.md`
   - Reload initiative config
   - Render track, audience, phase, and next-step guidance

## Key State

- `target_root`
- `initiative_roots`
- `dirty_state`
- `target_branch`
- `initiative_config`

## Output Artifacts

- None. `/switch` changes the checked-out control-repo branch only.