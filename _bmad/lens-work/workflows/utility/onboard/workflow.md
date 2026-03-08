# /onboard Workflow

**Phase:** Utility
**Purpose:** Bootstrap a new user in the control repo without committing secrets.

## Pre-conditions

- Control repo is a git repository with a remote configured
- `bmad.lens.release/_bmad/lens-work/` is accessible

## Steps

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

Check if the governance repo is cloned at the configured path (from `governance-setup.yaml` if it exists, otherwise use defaults from `lifecycle.yaml`).

If governance repo is missing:
> Governance repo not found at `{path}`. Clone it with:
> `git clone {governance_remote_url} {local_path}`

Governance repo is a hard prerequisite (Design Axiom A3).

### Step 4: Create Profile

Create `_bmad-output/lens-work/profile.yaml` with non-secret user configuration:

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

### Step 5: Run Health Check

Verify all systems are operational:

| Check | Method | Expected |
|-------|--------|----------|
| Provider auth | `provider-adapter validate-auth` | authenticated |
| Governance repo | File system check at configured path | directory exists |
| Release module version | Read `module.yaml` version | semver present |
| Workspace structure | Check `_bmad-output/lens-work/` exists | directory exists |

Report all checks with pass/fail status.

### Step 6: Report Next Command

On successful onboarding:

> ✅ Onboarding complete! You're set up as {role} in the {domain} domain.
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
| Governance repo missing | Provide clone command |
| Release module not found | "Release module not found at expected path. Verify setup." |

## Dependencies

- Provider adapter skill — for provider detection and auth validation
- `lifecycle.yaml` — for governance repo defaults and data zone definitions
