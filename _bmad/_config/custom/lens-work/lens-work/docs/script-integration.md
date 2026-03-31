# lens-work Script Integration Summary

## Changes Made

### 1. Created New Generic PR Creation Scripts

**New Files:**
- `_bmad/lens-work/scripts/create-pr.ps1` — PowerShell PR creation via GitHub API + PAT
- `_bmad/lens-work/scripts/create-pr.sh` — Bash PR creation via GitHub API + PAT

**Features:**
- Creates PRs between any two branches.
- Uses GitHub REST API directly with PAT from `profile.yaml` or environment.
- Never uses `gh` CLI.
- Supports GitHub and Azure DevOps with fallback to manual URLs.
- Returns structured output for downstream workflows.
- Falls back to manual instructions if PAT is unavailable.

### 2. Updated Phase Routers to Use create-pr Script

**Modified Workflows:**
- `/preplan` — Uses `create-pr.ps1` for phase PRs.
- `/businessplan` — Ready for update.
- `/techplan` — Ready for update.
- `/devproposal` — Ready for update.
- `/sprintplan` — Uses `create-pr.ps1` for phase PRs.

**Change Pattern:**

```yaml
# OLD: Generic adapter (could use gh CLI)
invoke: git-orchestration.create-pr
params:
  source_branch: ${phase_branch}
  target_branch: ${audience_branch}

# NEW: Explicit script with PAT + API
invoke: script
script: "${PROJECT_ROOT}/_bmad/lens-work/scripts/create-pr.ps1"
params:
  SourceBranch: ${phase_branch}
  TargetBranch: ${audience_branch}
  Title: "[PHASE] ${initiative.id} — PhaseComplete"
  Body: "Phase complete with artifacts..."
```

### 3. Enhanced Existing Promote Script

**Existing Files:**
- `_bmad/lens-work/scripts/promote-branch.ps1`
- `_bmad/lens-work/scripts/promote-branch.sh`

These already implement PAT + GitHub API promotion flow.

### 4. Updated Promotion-Check Include

**File:** `_bmad/lens-work/workflows/includes/promotion-check.md`

**Changes:**
- Documents that promotion uses PAT + API scripts.
- Clarifies that `gh` CLI is never required.
- Shows script invocation examples using PAT.
- Notes supported environment variables.

## PAT Configuration

Both `create-pr.*` and `promote-branch.*` retrieve PAT from, in order:

1. `profile.yaml`
2. Environment variables such as `GITHUB_TOKEN` or `GH_TOKEN`
3. Manual PR creation fallback if no PAT is available

## Policy: Never Use gh CLI

- PR creation uses `create-pr.ps1/.sh`.
- Branch promotion uses `promote-branch.ps1/.sh`.
- Authentication uses PAT from profile or environment.
- API access goes directly through GitHub REST API.
- Manual URL fallback is provided when PAT is unavailable.

## Next Steps

1. Complete `businessplan`, `techplan`, and `devproposal` PR script integration.
2. Run end-to-end workflow testing from `preplan` through `sprintplan`.
3. Verify PAT configuration in `profile.yaml` or environment.
4. Keep user-facing documentation aligned with the script-based PR policy.