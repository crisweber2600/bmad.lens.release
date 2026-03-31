# Workflow Plan: module-management

## Goal

Compare the installed lens-work module version to release and guide the user through a safe, non-destructive update flow.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Load local and release module manifests
2. `steps/step-02-compare-report.md`
   - Compare versions and report update availability
3. `steps/step-03-update-guidance.md`
   - Confirm whether the user wants update guidance
   - Explain the update path from release to control repo
4. `steps/step-04-compatibility-closeout.md`
   - Summarize expected compatibility checks and close the workflow

## Key State

- `local_module`
- `release_module`
- `local_version`
- `latest_version`
- `update_available`
- `update_confirmed`

## Output Artifacts

- None. The workflow emits guided update information only.