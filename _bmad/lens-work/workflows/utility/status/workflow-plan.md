# Workflow Plan: status

## Goal

Produce a status snapshot for active initiatives using only git-derived state and provider PR metadata.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve the current branch and requested detail scope
2. `steps/step-02-scan-initiatives.md`
   - Discover initiative roots from branch topology
   - Handle the no-initiative empty state
3. `steps/step-03-derive-state.md`
   - Derive audience, phase, PR state, and pending action per initiative
   - Identify the current initiative from the active branch
4. `steps/step-04-render-report.md`
   - Render the compact status table
   - Expand into a detailed card when requested or when only one initiative exists

## Key State

- `detail_initiative`
- `current_branch`
- `current_initiative_root`
- `initiative_roots`
- `status_rows`
- `detail_rows`
- `empty_state`

## Output Artifacts

- None. This workflow renders a git-derived status report in chat.