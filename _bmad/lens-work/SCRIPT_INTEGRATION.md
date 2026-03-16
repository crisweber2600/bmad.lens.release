# lens-work Script Integration Summary

## Changes Made

### 1. Created New Generic PR Creation Scripts

**New Files:**
- `_bmad/lens-work/scripts/create-pr.ps1` — PowerShell PR creation via GitHub API + PAT
- `_bmad/lens-work/scripts/create-pr.sh` — Bash PR creation via GitHub API + PAT

**Features:**
- ✅ Creates PRs between any two branches (phase PRs, promotion PRs, etc.)
- ✅ Uses GitHub REST API directly with PAT from `profile.yaml` or environment
- ✅ **Never uses `gh` CLI** — always PAT + API
- ✅ Supports GitHub and Azure DevOps (with fallback to manual URLs)
- ✅ Returns structured output (URL, PR number) for downstream workflows
- ✅ Fallback to manual instructions if PAT not available

**Usage:**
```powershell
# PowerShell
.\_bmad\lens-work\scripts\create-pr.ps1 `
  -SourceBranch "feature-branch" `
  -TargetBranch "main" `
  -Title "[PHASE] My Phase Complete" `
  -Body "Phase artifacts ready for review"
```

```bash
# Bash
./_bmad/lens-work/scripts/create-pr.sh \
  --source "feature-branch" \
  --target "main" \
  --title "[PHASE] My Phase Complete" \
  --body "Phase artifacts ready for review"
```

### 2. Updated Phase Routers to Use create-pr Script

**Modified Workflows:**
- `/preplan` — Now uses `create-pr.ps1` for phase PRs ✅
- `/businessplan` — Ready for update (placeholder)
- `/techplan` — Ready for update (placeholder)
- `/devproposal` — Ready for update (placeholder)
- `/sprintplan` — Now uses `create-pr.ps1` for phase PRs ✅

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

**Existing File:**
- `_bmad/lens-work/scripts/promote-branch.ps1` — Already uses PAT + GitHub API ✅
- `_bmad/lens-work/scripts/promote-branch.sh` — Already uses PAT + GitHub API ✅

**No changes needed** — Already implements PAT + API methodology.

### 4. Updated Promotion-Check Include

**File:** `_bmad/lens-work/workflows/includes/promotion-check.md`

**Changes:**
- Added explicit documentation that promotion uses PAT + API scripts
- Clarified that `gh` CLI is never required
- Provided script invocation examples showing PAT usage
- Added note about environment variables (`$GITHUB_TOKEN`, `$GH_TOKEN`)

## PAT Configuration

Both `create-pr.ps1` and `promote-branch.ps1` retrieve PAT from (in order):

1. **profile.yaml** — User's git credentials section:
   ```yaml
   git_credentials:
     - host: github.com
       pat: ghp_xxxxxxxxxxxx
     - host: api.github.com
       pat: ghp_yyyyyyyyyyyyy
   ```

2. **Environment Variables:**
   - `$GITHUB_TOKEN` (standard GitHub variable)
   - `$GH_TOKEN` (alternative)
   - `$env:GITHUB_TOKEN` (PowerShell)

3. **Fallback** — If no PAT available, script provides manual PR creation URL

## Policy: Never Use `gh` CLI

✅ **All promotion and PR operations now:**
- Use PAT + GitHub REST API directly
- Invoke scripts that handle PAT retrieval and API calls
- Never invoke `gh` CLI
- Support offline/CI environments without `gh` installation

## Next Steps

1. **Complete businessplan, techplan, devproposal** — Update their PR creation sections to use `create-pr.ps1`
2. **Test end-to-end** — Run full workflow (preplan → sprintplan) and verify PRs are created via API
3. **Verify PAT configuration** — Ensure users have PAT set in `profile.yaml` or environment
4. **Document for users** — Add PR creation guide to project docs

## Files Changed

```
Scripts (New):
  _bmad/lens-work/scripts/create-pr.ps1        ✅ Created
  _bmad/lens-work/scripts/create-pr.sh         ✅ Created

Workflows (Updated):
  workflows/router/preplan/workflow.md         ✅ Uses create-pr.ps1
  workflows/router/sprintplan/workflow.md      ✅ Uses create-pr.ps1
  workflows/includes/promotion-check.md        ✅ Updated docs

Workflows (Ready for update):
  workflows/router/businessplan/workflow.md    ⏳ Needs create-pr integration
  workflows/router/techplan/workflow.md        ⏳ Needs create-pr integration
  workflows/router/devproposal/workflow.md     ⏳ Needs create-pr integration
```

## Policy Summary

| Aspect | Policy |
|--------|--------|
| PR Creation | Always use `create-pr.ps1/.sh` script |
| Branch Promotion | Always use `promote-branch.ps1/.sh` script |
| Authentication | Always use PAT (from profile.yaml or env vars) |
| API Access | Always GitHub REST API directly |
| CLI Tools | Never use `gh` CLI |
| Fallback | Manual URL instructions if PAT unavailable |
