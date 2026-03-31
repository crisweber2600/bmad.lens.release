# Workflow Plan: onboard

## Goal

Bootstrap a contributor into the control repo with verified provider auth, a usable governance repo, a committed non-secret profile, and a bootstrapped TargetProjects workspace.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Confirm git remote and detect provider context
2. `steps/step-02-auth-and-governance.md`
   - Validate provider authentication
   - Resolve or clone the governance repo
3. `steps/step-03-profile-and-bootstrap.md`
   - Write `_bmad-output/lens-work/personal/profile.yaml`
   - Bootstrap inventory-driven target-project clones
4. `steps/step-04-health-and-report.md`
   - Run health checks
   - Render onboarding results and next-command guidance

## Key State

- `remote_url`
- `provider`
- `auth_status`
- `governance_repo_path`
- `governance_remote_url`
- `profile_path`
- `clone_results`
- `health_checks`

## Output Artifacts

- `_bmad-output/lens-work/personal/profile.yaml`
- Local governance repo clone when missing
- TargetProjects clones for inventory-listed repositories