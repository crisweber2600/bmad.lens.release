# Skill: git-orchestration

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Encapsulates all git write operations for the lens-work lifecycle. Handles branch creation, commits, pushes, branch cleanup, and dirty working directory management. This is the WRITE counterpart to the read-only `git-state` skill.

## Read Operations

**NONE for state queries.** Use `git-state` skill for all read/query operations. This skill performs reads only as preconditions for writes (e.g., validating branch name before creation).

## Operations

### `create-branch`

Create a new branch following lifecycle.yaml naming conventions.

**Variants:**

| Branch Type | Pattern | Created From |
|-------------|---------|-------------|
| Initiative root | `{initiative-root}` | Control repo default branch |
| Audience | `{initiative-root}-{audience}` | Previous audience or initiative root |
| Phase | `{initiative-root}-{audience}-{phase}` | Audience branch |

**Algorithm:**
```bash
# 1. Validate branch name against lifecycle.yaml patterns
# 2. Check branch doesn't already exist
# 3. Create from appropriate parent
git checkout "${PARENT_BRANCH}"
git checkout -b "${NEW_BRANCH}"
git push -u origin "${NEW_BRANCH}"
```

**Validation rules:**
- Branch name MUST match lifecycle.yaml `branch_patterns`
- Audience token MUST be one of: `small`, `medium`, `large`, `base`
- Phase name MUST be defined in lifecycle.yaml `phases`
- Initiative root MUST be slug-safe (lowercase alphanumeric + hyphens)
- Reject invalid names with clear error message

**Audience branch creation policy: LAZY**
- At init: create `{root}` and `{root}-small` ONLY
- Additional audience branches created on-demand at promotion time
- Branch existence becomes meaningful signal (if `{root}-medium` exists, promotion was attempted)

---

### `commit-artifacts`

Commit files to the current branch with structured commit messages.

**Commit message format:**
```
[{PHASE}] {initiative} — {description}
```

Examples:
```
[PREPLAN] foo-bar-auth — product brief draft
[TECHPLAN] foo-bar-auth — architecture document complete
[PROMOTE] foo-bar-auth — small→medium promotion artifacts
```

**Algorithm:**
```bash
# 1. Stage relevant files
git add "${FILE_PATHS}"
# 2. Commit with structured message
git commit -m "[${PHASE}] ${INITIATIVE} — ${DESCRIPTION}"
```

**Push convention:**
- **Reviewable checkpoint:** commit + push (phase bundle complete or user requests)
- **Draft save:** commit only, no push (incremental work)
- Every commit that is pushed MUST be immediately followed by `git push`

---

### `push`

Push the current branch to the configured remote.

**Algorithm:**
```bash
git push origin "${CURRENT_BRANCH}"
```

**Rules:**
- Push at reviewable checkpoints, not every draft write
- Never force-push without explicit user confirmation
- Use configured remote (from git config)

---

### `delete-branch`

Delete a phase branch after its PR has been merged.

**Algorithm:**
```bash
# 1. VERIFY PR is merged before allowing deletion
provider-adapter query-pr-status \
  --head "${PHASE_BRANCH}" \
  --base "${AUDIENCE_BRANCH}" \
  --state merged

# 2. Only if merged PR found:
git branch -d "${PHASE_BRANCH}"          # Delete local
git push origin --delete "${PHASE_BRANCH}"  # Delete remote
```

**Safety rules:**
- **NEVER** delete a branch without verifying its PR is merged
- Verify PR merge status via provider adapter before any deletion
- Log deletion in commit message of the target branch

---

### `validate-branch-name`

Validate a proposed branch name against lifecycle.yaml patterns.

**Algorithm:**
```bash
# Parse proposed name against patterns
# Check: slug-safe characters only (lowercase, digits, hyphens)
# Check: audience token is valid
# Check: phase name is defined in lifecycle.yaml
# Return: valid/invalid with reason
```

**Output:**
```yaml
name: foo-bar-auth-small-techplan
valid: true
parsed:
  initiative_root: foo-bar-auth
  audience: small
  phase: techplan
```

Invalid example:
```yaml
name: Foo Bar Auth
valid: false
reason: "Branch name must be slug-safe (lowercase alphanumeric and hyphens only)"
```

---

### `check-dirty`

Detect uncommitted changes in the working directory.

**Algorithm:**
```bash
# Check for uncommitted changes
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ]; then
  echo "dirty"
else
  echo "clean"
fi
```

**Output:**
```yaml
status: dirty    # dirty | clean
files_changed: 3
files:
  - _bmad-output/lens-work/initiatives/foo/bar/phases/techplan/architecture.md
  - _bmad-output/lens-work/initiatives/foo/bar/auth.yaml
```

**When dirty directory detected, present options:**
1. **Commit** — commit current changes before proceeding
2. **Stash** — `git stash` to save work temporarily
3. **Abort** — cancel the operation

**NEVER silently discard uncommitted work.**

---

## Git Discipline Rules

1. Clean working directory before any branch operation
2. Targeted commits — only files relevant to current workflow
3. Push at reviewable checkpoints (not every draft write)
4. Never force-push without explicit user confirmation
5. Structured commit messages: `[PHASE] {initiative} — {description}`
6. Branch names derived from lifecycle.yaml, never hardcoded

---

## Provider Operations

Git-orchestration includes provider adapter operations that abstract PR management behind a common interface. MVP implements GitHub via the `promote-branch` script + GitHub REST API with PAT-based authentication. The `gh` CLI is NOT required — all PR operations use direct REST API calls. Azure DevOps support is post-MVP.

### Scripts

The module includes cross-platform scripts in `scripts/` that handle PR creation and PAT management without requiring any provider CLI:

| Script | Purpose |
|--------|--------|
| `promote-branch.ps1` / `promote-branch.sh` | Branch promotion, PR creation via REST API, branch cleanup |
| `store-github-pat.ps1` / `store-github-pat.sh` | Secure PAT collection into environment variables (run outside AI context) |

### PAT Resolution Order

PR operations require a GitHub PAT. The resolution order is:

1. **Environment variable (host-specific):**
   - `github.com` → `GITHUB_PAT` → `GH_TOKEN`
   - Enterprise → `GH_ENTERPRISE_TOKEN` → `GH_TOKEN`
2. **Profile file:** `_bmad-output/lens-work/personal/profile.yaml` → `git_credentials[].pat`
3. **Fallback:** URL-only mode (prints PR comparison URL for manual creation)

**CRITICAL (NFR4):** PATs are stored ONLY in environment variables or OS-level persistence. They are NEVER written to any git-tracked file. The `store-github-pat` scripts handle secure collection outside of any AI/LLM context.

---

### `detect-provider`

Detect the configured PR provider from the git remote URL.

**Algorithm:**
```bash
REMOTE_URL=$(git remote get-url origin)

# GitHub detection (including GitHub Enterprise)
if echo "$REMOTE_URL" | grep -qi "github"; then
  PROVIDER="github"
# Azure DevOps detection (post-MVP)
elif echo "$REMOTE_URL" | grep -qiE "dev.azure.com|visualstudio.com"; then
  PROVIDER="azure-devops"
# GitLab detection
elif echo "$REMOTE_URL" | grep -qi "gitlab"; then
  PROVIDER="gitlab"
else
  PROVIDER="unknown"
fi
```

**Output:**
```yaml
provider: github
remote_url: https://github.com/user/repo.git
host: github.com
org: user
repo: repo
```

The `promote-branch` scripts include full URL parsing for GitHub, GitLab, and Azure DevOps (HTTPS and SSH formats).

---

### `validate-auth`

Validate that the user has a PAT configured for the detected provider.

**Algorithm:**
```bash
# Check environment variables for PAT
if [[ "$HOST" == "github.com" ]]; then
  PAT="${GITHUB_PAT:-${GH_TOKEN:-}}"
else
  PAT="${GH_ENTERPRISE_TOKEN:-${GH_TOKEN:-}}"
fi

# Validate PAT works via REST API
if [[ -n "$PAT" ]]; then
  curl -s -H "Authorization: token $PAT" "$API_BASE/user" | jq -r .login
fi
```

**If auth fails:** Guide user to set up PAT:
```
No PAT found. Run the store-github-pat script outside of this chat:
  Windows: .\_bmad\lens-work\scripts\store-github-pat.ps1
  macOS/Linux: ./_bmad/lens-work/scripts/store-github-pat.sh
Then restart your terminal and try again.
```

**CRITICAL (NFR4):** Never write PATs, tokens, or credentials to any git-tracked file. PATs are stored exclusively in environment variables (session or user-scoped). The `store-github-pat` script collects PATs in a dedicated terminal session — never within an AI chat context.

**Input:** none
**Output:** `{ authenticated: boolean, user: string?, pat_source: string?, error: string? }`

---

### `create-pr`

Create a pull request via the `promote-branch` script or direct REST API call.

**Preferred method — promote-branch script:**
```bash
# The script handles PAT resolution, branch push, PR creation, and cleanup
./_bmad/lens-work/scripts/promote-branch.sh \
  -s "${SOURCE_BRANCH}" \
  -t "${TARGET_BRANCH}"
```

**Direct REST API method (used by the script internally):**
```bash
curl -s -X POST "${API_BASE}/repos/${ORG}/${REPO}/pulls" \
  -H "Authorization: token ${PAT}" \
  -H "Content-Type: application/json" \
  -d '{"head": "'${SOURCE_BRANCH}'", "base": "'${TARGET_BRANCH}'", "title": "'${TITLE}'", "body": "'${BODY}'"}'
```

**Input:**
```yaml
title: "[TECHPLAN] foo-bar-auth — Architecture Review"
body: |
  ## Phase Completion: TechPlan
  ### Artifacts
  - architecture.md
source_branch: foo-bar-auth-small-techplan
target_branch: foo-bar-auth-small
```

**Output:** `{ pr_url: string, pr_number: integer }`

**Fallback:** If no PAT is available, the script prints the PR comparison URL for manual creation in the browser.

---

### `query-pr-status`

Query the status of a pull request by branch names.

**GitHub REST API implementation:**
```bash
curl -s -H "Authorization: token ${PAT}" \
  "${API_BASE}/repos/${ORG}/${REPO}/pulls?head=${ORG}:${SOURCE_BRANCH}&base=${TARGET_BRANCH}&state=all"
```

**Output:**
```yaml
state: merged      # open | merged | closed
review_decision: approved   # approved | changes_requested | review_required | null
merged_at: "2026-03-08T15:30:00Z"   # null if not merged
```

---

### `list-prs`

List pull requests filtered by branch pattern and state.

**GitHub REST API implementation:**
```bash
curl -s -H "Authorization: token ${PAT}" \
  "${API_BASE}/repos/${ORG}/${REPO}/pulls?base=${TARGET_BRANCH}&state=closed" \
  | jq '[.[] | select(.merged_at != null)]'
```

**Output:**
```yaml
prs:
  - number: 42
    title: "[TECHPLAN] foo-bar-auth — Architecture Review"
    state: merged
    source: foo-bar-auth-small-techplan
    target: foo-bar-auth-small
```

---

### `get-pr-body`

Retrieve the body/description of a specific PR.

**GitHub REST API implementation:**
```bash
curl -s -H "Authorization: token ${PAT}" \
  "${API_BASE}/repos/${ORG}/${REPO}/pulls/${PR_NUMBER}" \
  | jq -r '.body'
```

**Input:** `{ pr_number: integer }`
**Output:** `{ body: string }`

---

### Azure DevOps Adapter (Post-MVP Reference)

| Operation | Azure DevOps Equivalent |
|-----------|------------------------|
| `detect-provider` | Parse `dev.azure.com` or `visualstudio.com` from remote URL |
| `validate-auth` | Check `AZURE_DEVOPS_PAT` env var or `az account show` |
| `create-pr` | `az repos pr create --title --description --source-branch --target-branch` or REST API |
| `query-pr-status` | `az repos pr show --id {id} --query "{status, reviewers}"` or REST API |
| `list-prs` | `az repos pr list --target-branch --source-branch --status` or REST API |
| `get-pr-body` | `az repos pr show --id {id} --query "description"` or REST API |

### Credential Security (NFR4)

- PATs stored EXCLUSIVELY in environment variables (session or user-scoped)
- **NEVER** write PATs, tokens, or credentials to any git-tracked file
- Auth validation checks environment variables and validates via REST API
- PAT setup uses `store-github-pat` scripts run OUTSIDE of AI chat context
- If auth fails, guide user to run the `store-github-pat` script in a separate terminal

**Dependencies:**
- `curl` + `jq` — used by promote-branch scripts for REST API calls (widely available)
- `git` — required for all operations
- No `gh` CLI required — all GitHub operations use REST API with PAT
- `az` CLI — optional for Azure DevOps operations (post-MVP)

---

## Authority Domain Enforcement

**Design Axiom A3:** Authority domains must be explicit. Cross-authority writes are **HARD ERRORS**.

Before ANY write operation (commit, file creation, file modification), validate the target path against authority rules:

### Enforcement Rules

| Target Path | Rule | Error Message |
|-------------|------|---------------|
| `bmad.lens.release/` | ALWAYS blocked for initiative writes | `❌ BLOCK — release repo is read-only at runtime. Write to _bmad-output/lens-work/initiatives/ instead.` |
| Governance repo path | Blocked except governance PR proposals | `❌ BLOCK — governance lives in its own repo. Propose changes via governance PR.` |
| `.github/` | Not modified during initiative work | `❌ BLOCK — adapter layer is not modified during initiative work.` |
| Outside `_bmad-output/lens-work/initiatives/` | Blocked for initiative workflow writes | `❌ BLOCK — initiative artifacts must be written to _bmad-output/lens-work/initiatives/{path}/` |

### Validation Algorithm

```
function validate_write_target(path, context):
  if path starts with "bmad.lens.release/":
    HARD ERROR — release repo is read-only at runtime
  if path is within governance repo:
    if context != "governance-pr-proposal":
      HARD ERROR — governance lives in its own repo
  if context == "initiative-workflow":
    if path not within "_bmad-output/lens-work/initiatives/":
      HARD ERROR — initiative artifacts must be in initiative directory
  return ALLOWED
```

### Exception: Governance PR Proposals

@lens MAY propose a governance PR (submit PR to governance repo) but cannot directly write files there. The proposal flow creates a PR in the governance repo for human review.

## Dependencies

- `lifecycle.yaml` — for branch naming patterns, valid phases, valid audiences
- Provider adapter — for PR merge state verification before branch cleanup
- `git-state` skill — for reading current state before write operations
