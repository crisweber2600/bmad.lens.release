# Workflow Plan: upgrade

## Goal

Detect the installed LENS schema version, compute a safe branch rename plan using `lifecycle.yaml` migration descriptors, confirm with the user, apply local branch renames, write `LENS_VERSION`, and commit — leaving the control repo in a verified v3 state.

## Step Structure

1. `steps/step-01-detect.md`
   - Read `LENS_VERSION` (missing is acceptable)
   - Read `schema_version` and `migrations` from `lifecycle.yaml`
   - Determine `detected_version` (`missing`, `2`, `3`, etc.)
   - If already at target version, exit with "already up to date" message
   - Identify applicable migration paths

2. `steps/step-02-plan-renames.md`
   - Run `git branch` to list all local branches
   - Apply audience-to-milestone mapping from migration descriptors
   - Partition branches into: milestone renames, phase-branch notes, no-op
   - Build `rename_plan` (old name → new name) for milestone-root branches
   - Build `phase_branch_notes` for v2-style phase branches

3. `steps/step-03-confirm-and-apply.md`
   - Render the rename plan as a table
   - Render phase-branch notes as advisories (not renamed automatically)
   - Ask user to confirm before applying any changes
   - If confirmed: run `git branch -m {old} {new}` for each rename
   - Output push commands for remote branch updates (not auto-pushed)

4. `steps/step-04-write-version.md`
   - Write `LENS_VERSION` with the target schema_version value
   - Stage and commit: `git add LENS_VERSION && git commit -m "chore: upgrade to LENS v{version}"`
   - Report success and next command (`/next`)

## Key State

- `detected_version` — version read from LENS_VERSION or `missing`
- `target_version` — schema_version from lifecycle.yaml
- `migration` — applicable migration descriptor from lifecycle.yaml
- `branch_scan` — raw list of local branches
- `rename_plan` — list of {from, to} rename operations
- `phase_branch_notes` — list of v2 phase branches needing manual review
- `renames_applied` — count of successful renames

## Output Artifacts

- `LENS_VERSION` file committed to control repo root
- Renamed local milestone branches
- Console output: remote push commands for user to run
