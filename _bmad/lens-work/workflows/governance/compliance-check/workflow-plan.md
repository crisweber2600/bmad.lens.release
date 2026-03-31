# Workflow Plan: compliance-check

## Goal

Run constitution-backed artifact compliance checks for the active initiative and surface a result suitable for PR embedding or gate enforcement.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve initiative, phase, and artifacts path
2. `steps/step-02-resolve-constitution.md`
   - Invoke `constitution.resolve-constitution`
3. `steps/step-03-run-compliance.md`
   - Invoke `constitution.check-compliance`
4. `steps/step-04-render-result.md`
   - Render the compliance summary or fail on hard-gate violations

## Key State

- `initiative_state`
- `initiative_config`
- `current_phase`
- `artifacts_path`
- `resolved_constitution`
- `compliance_result`

## Output Artifacts

- None. The workflow emits a compliance summary for callers or users.