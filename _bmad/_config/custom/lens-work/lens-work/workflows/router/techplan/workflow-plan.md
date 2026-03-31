# Workflow Plan: techplan

## Goal

Launch the TechPlan phase on the small audience, generate architecture and technical design artifacts, and close the phase with a reviewable PR.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Validate inherited planning artifacts and prepare the techplan phase branch
2. `steps/step-02-select-mode.md`
   - Capture interactive or batch mode
   - Decide whether API contracts are in scope
3. `steps/step-03-run-workflows.md`
   - Generate architecture and technical decisions
   - Generate optional API contracts
   - Run architecture readiness validation
4. `steps/step-04-closeout.md`
   - Commit artifacts, create the phase PR, update state, and surface `/devproposal`

## Key State

- `initiative`
- `lifecycle`
- `phase_branch`
- `audience_branch`
- `docs_path`
- `constitutional_context`
- `execution_mode`
- `include_api_contracts`
- `pr_result`

## Output Artifacts

- `architecture.md`
- `tech-decisions.md`
- Optional `api-contracts.md`
- Updated initiative state and techplan phase PR