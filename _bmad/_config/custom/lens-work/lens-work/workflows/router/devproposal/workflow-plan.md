# Workflow Plan: devproposal

## Goal

Launch the DevProposal phase on the medium audience, generate epics and stories, run readiness gates, and close the phase with a reviewable PR.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Validate small-to-medium promotion and inherited planning artifacts
   - Prepare the devproposal phase branch
2. `steps/step-02-select-mode.md`
   - Capture interactive or batch mode
   - Decide whether epic stress gates run in the current pass
3. `steps/step-03-run-workflows.md`
   - Generate epics and stories
   - Run adversarial and party-mode epic stress gates
   - Run readiness validation
4. `steps/step-04-closeout.md`
   - Commit artifacts, create the phase PR, update state, and surface `/sprintplan`

## Key State

- `initiative`
- `lifecycle`
- `phase_branch`
- `audience_branch`
- `docs_path`
- `constitutional_context`
- `execution_mode`
- `run_epic_stress_gate`
- `pr_result`

## Output Artifacts

- `epics.md`
- `stories.md`
- `readiness-checklist.md`
- Optional epic party-mode review artifacts
- Updated initiative state and devproposal phase PR