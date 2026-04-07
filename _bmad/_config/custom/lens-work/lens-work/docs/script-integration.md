# lens-work Script Integration Reference

**Module:** lens-work v3.1  
**Policy:** All git operations use direct GitHub/Azure DevOps REST API calls with PAT authentication. The `gh` CLI is never required.

## Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `scripts/create-pr.ps1` | PowerShell (Windows) | Create a PR between any two branches via REST API |
| `scripts/create-pr.sh` | Bash (Linux/macOS) | Create a PR between any two branches via REST API |
| `scripts/promote-branch.ps1` | PowerShell (Windows) | Branch promotion + PR creation via REST API |
| `scripts/promote-branch.sh` | Bash (Linux/macOS) | Branch promotion + PR creation via REST API |
| `scripts/store-github-pat.ps1` | PowerShell (Windows) | Secure PAT setup into environment (run outside AI chat) |
| `scripts/store-github-pat.sh` | Bash (Linux/macOS) | Secure PAT setup into environment (run outside AI chat) |

## PAT Resolution Order

Both `create-pr.*` and `promote-branch.*` resolve authentication in this order:

1. `GITHUB_PAT` environment variable
2. `GH_TOKEN` environment variable
3. `profile.yaml` (in `_bmad-output/lens-work/personal/`)
4. URL-only fallback (manual PR creation instructions provided)

## PR Creation

`create-pr.ps1/.sh` creates PRs between any two branches:

```bash
# Bash
./lens.core/_bmad/lens-work/scripts/create-pr.sh \
  --source-branch "${phase_branch}" \
  --target-branch "${audience_branch}" \
  --title "[PHASE] ${initiative_id} — Phase Complete" \
  --body "Phase complete with artifacts committed to ${phase_branch}."
```

```powershell
# PowerShell
.\lens.core\_bmad\lens-work\scripts\create-pr.ps1 `
  -SourceBranch "${phase_branch}" `
  -TargetBranch "${audience_branch}" `
  -Title "[PHASE] ${initiative_id} — Phase Complete" `
  -Body "Phase complete with artifacts committed to ${phase_branch}."
```

**Features:**
- Uses GitHub (or Azure DevOps) REST API directly
- Supports provider-specific URL patterns
- Returns structured output for downstream workflow steps
- Falls back to manual instructions with the PR URL if no PAT is available

## Branch Promotion

`promote-branch.ps1/.sh` combines branch creation and PR in one operation:

```bash
./lens.core/_bmad/lens-work/scripts/promote-branch.sh \
  --source-branch "${audience_branch}" \
  --target-branch "next-${audience_branch}" \
  --title "[PROMOTE] ${initiative_id} — ${audience} → ${next_audience}"
```

## Workflow Integration Pattern

Phase-completing workflows invoke `create-pr` directly:

```yaml
# Workflow step pattern (in steps/*.md)
invoke: script
script: "${PROJECT_ROOT}/lens.core/_bmad/lens-work/scripts/create-pr.ps1"
params:
  SourceBranch: ${phase_branch}
  TargetBranch: ${audience_branch}
  Title: "[PHASE] ${initiative.id} — Phase Complete"
  Body: "Phase complete. Artifacts committed."
```

## Policy: Never Use gh CLI

- PR creation → `create-pr.ps1/.sh`
- Branch promotion → `promote-branch.ps1/.sh`
- PAT management → `store-github-pat.ps1/.sh` (setup only, run by user outside AI chat)
- All API access → GitHub/Azure DevOps REST API directly
- No `gh`, `az`, or other external CLIs required at runtime

## Next Steps

1. Complete `businessplan`, `techplan`, and `devproposal` PR script integration.
2. Run end-to-end workflow testing from `preplan` through `sprintplan`.
3. Verify PAT configuration in `profile.yaml` or environment.
4. Keep user-facing documentation aligned with the script-based PR policy.