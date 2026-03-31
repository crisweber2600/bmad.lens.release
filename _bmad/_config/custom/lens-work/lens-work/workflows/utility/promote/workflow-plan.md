# Workflow Plan: promote

## Goal

Provide a packaged `/promote` alias entry under utility that delegates to the core audience-promotion workflow.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative and current audience
2. `steps/step-02-route.md`
   - Exit if already at base
   - Otherwise invoke the core audience-promotion workflow

## Key State

- `initiative_state`
- `current_audience`
- `next_audience`

## Output Artifacts

- None. This workflow hands off into the core promotion workflow.