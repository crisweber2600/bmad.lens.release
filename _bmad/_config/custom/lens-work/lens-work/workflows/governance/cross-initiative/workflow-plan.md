# Workflow Plan: cross-initiative

## Goal

Run the sensing skill against the active initiative, classify overlap severity under constitution rules, and return an actionable sensing report.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative context and current scope
2. `steps/step-02-run-sensing.md`
   - Invoke `sensing.scan-initiatives`
3. `steps/step-03-resolve-gate.md`
   - Resolve `sensing_gate_mode` from constitution
4. `steps/step-04-render-result.md`
   - Render overlaps and optionally enforce a hard gate

## Key State

- `initiative_state`
- `initiative_config`
- `sensing_report`
- `resolved_constitution`
- `sensing_result`

## Output Artifacts

- None. The workflow emits a sensing result for callers or direct users.