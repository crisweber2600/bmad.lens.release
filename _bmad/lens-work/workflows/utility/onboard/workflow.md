# /onboard Workflow

**Phase:** Utility
**Purpose:** Bootstrap a new user in the control repo without committing secrets.

## Pre-conditions

- Control repo is a git repository with a remote configured
- `bmad.lens.release/_bmad/lens-work/` is accessible

## Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
2. If preflight reports missing authority repos, continue onboarding so this workflow can clone or repair required repos.

### Step 1: Detect PR Provider

Use the provider-adapter skill to detect the configured PR provider from the git remote URL.

```bash
REMOTE_URL=$(git remote get-url origin)
```

Parse the URL to determine provider (GitHub or Azure DevOps). Store result for subsequent steps.

### Step 2: Validate Authentication

Check that the user has a PAT configured via environment variables.

**GitHub:**
```bash
# Check for PAT in environment variables
if [[ "$HOST" == "github.com" ]]; then
  PAT="${GITHUB_PAT:-${GH_TOKEN:-}}"
else
  PAT="${GH_ENTERPRISE_TOKEN:-${GH_TOKEN:-}}"
fi

# Validate via REST API
curl -s -H "Authorization: token $PAT" "$API_BASE/user" | jq -r .login
```

If auth fails, guide the user:
> No PAT found. Run the store-github-pat script **outside of this chat** in a separate terminal:
>   Windows: `.\_bmad\lens-work\scripts\store-github-pat.ps1`
>   macOS/Linux: `./_bmad/lens-work/scripts/store-github-pat.sh`
> Then restart your terminal and try `/onboard` again.

**CRITICAL:** Never write PATs, tokens, or credentials to any git-tracked file. PATs are collected by the `store-github-pat` script in a dedicated terminal session — never within an AI chat.

### Step 3: Verify Governance Repo

Resolve governance configuration from `_bmad-output/lens-work/governance-setup.yaml` when present. If missing, use lifecycle defaults:

- `path`: `TargetProjects/lens/lens-governance`
- `remote_url`: infer from org/provider context or prompt user once if not derivable

If the governance repo is missing locally, clone it automatically:

```bash
git clone {governance_remote_url} {governance_local_path}
```

Then verify `repo-inventory.yaml` exists in the governance repo root. Governance remains a hard prerequisite (Design Axiom A3).

### Step 4: Create Profile

Create `_bmad-output/lens-work/personal/profile.yaml` with non-secret user configuration:

```yaml
# profile.yaml — committed, non-secret user profile
role: contributor           # contributor | lead | stakeholder
domain: null                # primary domain (set on first /new-domain)
provider: github            # detected from remote URL
batch_preferences:
  question_mode: guided     # guided | yolo | defaults
  auto_checkpoint: true     # auto-commit at reviewable checkpoints
target_projects_path: TargetProjects
created: {ISO8601}
```

This file IS committed to git (Domain 1 artifact). It contains NO secrets.

### Step 5: Bootstrap Target Project Clones

Read `{governance_local_path}/repo-inventory.yaml` and bootstrap repository clones automatically.

Behavior:

1. Parse inventory entries from common schemas:
  - list keys: `repositories`, `repos`, or top-level list
  - remote keys: `remote_url`, `repo_url`, `remote`, or `url`
  - local path keys: `local_path`, `clone_path`, or `path`
2. Resolve each local path relative to control repo root.
3. For each entry:
  - if `{local_path}/.git` exists: mark as `already-present`
  - if missing and remote URL present: run `git clone {remote_url} {local_path}`
  - if missing required fields: mark as `skipped` with reason
4. Continue processing even if one clone fails; collect per-repo status.

Output a compact result table:

```
| Repo | Path | Action | Status |
|------|------|--------|--------|
| lens-governance | TargetProjects/lens/lens-governance | verify | ✅ present |
| NorthStarET | TargetProjects/northstar/NorthStarET | clone | ✅ cloned |
| OldNorthStar | TargetProjects/northstar/OldNorthStar | clone | ⚠️ failed |
```

Do not defer onboarding completeness to `/reconcile` for repositories listed in the inventory.

### Step 6: Run Health Check

Verify all systems are operational:

| Check | Method | Expected |
|-------|--------|----------|
| Provider auth | `provider-adapter validate-auth` | authenticated |
| Governance repo | File system check at configured path | directory exists |
| Repo inventory | `{governance_local_path}/repo-inventory.yaml` (in governance repo) | file exists |
| TargetProjects bootstrap | Clone status table from Step 5 | no fatal failures |
| Release module version | Read `module.yaml` version | semver present |
| Workspace structure | Check `_bmad-output/lens-work/` exists | directory exists |

Report all checks with pass/fail status.

### Step 7: Report Next Command

On successful onboarding:

> ✅ Onboarding complete! You're set up as {role} in the {domain} domain.
> 
> TargetProjects bootstrap: {cloned_count} cloned, {existing_count} already present, {failed_count} failed.
> 
> Run `/next` to see what to work on, or `/status` for the full picture.
> To create your first initiative, try `/new-domain`.

## Profile Schema

| Field | Type | Description | Secret? |
|-------|------|-------------|---------|
| `role` | string | User role (contributor/lead/stakeholder) | No |
| `domain` | string | Primary domain | No |
| `provider` | string | Detected PR provider | No |
| `batch_preferences.question_mode` | string | Interaction style | No |
| `batch_preferences.auto_checkpoint` | boolean | Auto-commit behavior | No |
| `target_projects_path` | string | Path to target project clones | No |
| `created` | datetime | Onboarding timestamp | No |

## Error Handling

| Error | Recovery |
|-------|----------|
| Git not initialized | "This directory is not a git repo. Run `git init` first." |
| No remote configured | "No git remote found. Add one with `git remote add origin {url}`." |
| Provider auth fails | Guide to run `store-github-pat` script (GitHub) or `az login` (Azure DevOps) |
| Governance repo missing | Auto-clone using configured/default governance remote and path |
| Repo inventory missing | "`repo-inventory.yaml` not found in governance repo. Add it before onboarding can bootstrap TargetProjects." |
| Release module not found | "Release module not found at expected path. Verify setup." |

## Dependencies

- Provider adapter skill — for provider detection and auth validation
- `lifecycle.yaml` — for governance repo defaults and data zone definitions
