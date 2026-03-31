# Workflow Plan: resolve-constitution

## Goal

Resolve the effective constitution for the active initiative and return it to promotion or compliance callers.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative configuration and derived governance identity
2. `steps/step-02-resolve.md`
   - Invoke `constitution.resolve-constitution`
3. `steps/step-03-render-result.md`
   - Return the resolved constitution and a concise summary

## Key State

- `initiative_state`
- `initiative_config`
- `resolution_context`
- `resolved_constitution`

## Output Artifacts

- None. The workflow returns the resolved constitution to callers.