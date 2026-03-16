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
- Initiative root MUST be slug-safe (`{domain}-{service}-{feature}` pattern where each component is lowercase alphanumeric)
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
# Check: slug-safe root pattern from normalized components
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

Domain-only example (no audience — domains don't have audience branches):
```yaml
name: test
valid: true
parsed:
  initiative_root: test
  scope: domain
```

Feature-level example:
```yaml
name: test-worker-small
valid: true
parsed:
  initiative_root: test-worker
  audience: small
  phase: null
```

Invalid example:
```yaml
name: Foo Bar Auth
valid: false
reason: "Name components must be slug-safe (lowercase alphanumeric only)"
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

### `verify-clean-state`

Verify the working directory is clean. Halts workflow if uncommitted changes detected.
Unlike `check-dirty` (which reports status), this operation is a **hard gate**.

**Algorithm:**
```bash
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ]; then
  echo "❌ Dirty working directory — commit or stash changes before proceeding."
  echo "$DIRTY"
  exit 1
fi
echo "✅ Working directory clean"
```

**Rules:**
- Used as a pre-condition for branch operations and workflow starts
- HALTS on dirty state (exit 1) — does not prompt for options (use `check-dirty` for interactive)

---

### `checkout-branch`

Checkout an existing branch.

**Algorithm:**
```bash
git checkout "${BRANCH}"
```

---

### `pull-latest`

Pull latest changes from remote for the current branch.

**Algorithm:**
```bash
git pull origin "$(git symbolic-ref --short HEAD)"
```

---

### `start-phase`

Create a phase branch from its parent and push to remote.

**Algorithm:**
```bash
PHASE_BRANCH="${INITIATIVE_ROOT}-${PHASE_NAME}"
git checkout "${PARENT_BRANCH}"
git pull origin "${PARENT_BRANCH}"
git checkout -b "${PHASE_BRANCH}"
git push -u origin "${PHASE_BRANCH}"
echo "✅ Phase branch created: ${PHASE_BRANCH}"
```

**Input:**
```yaml
phase_name: "dev"
initiative_root: "foo-bar-auth"
parent_branch: "base"
```

---

### `commit-and-push`

Stage specified files, commit with a message, and push in one operation.

**Algorithm:**
```bash
cd "${REPO_PATH}"
git add ${FILE_PATHS}
git commit -m "${MESSAGE}"
git push origin "${BRANCH}"
```

---

### `exec`

Execute a raw git command and return stdout + exit code.

**Algorithm:**
```bash
RESULT=$(git ${GIT_ARGS} 2>&1)
EXIT_CODE=$?
```

**Output:**
```yaml
stdout: "${RESULT}"
exit_code: ${EXIT_CODE}
```

---

### `start-workflow`

Mark the beginning of a sub-workflow context (e.g., code-review, retrospective).
Used to signal persona switch (e.g., developer → QA for code review).

**Algorithm:**
```yaml
session.active_workflow = "${WORKFLOW_NAME}"
session.workflow_start_agent = session.current_agent
```

---

### `finish-workflow`

Return from a sub-workflow context to the previous agent.

**Algorithm:**
```yaml
session.current_agent = session.workflow_start_agent
session.active_workflow = null
```

**Rules:**
- Always paired with `start-workflow`
- Restores the agent persona that was active before the sub-workflow

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

Use `source_branch` and `target_branch` when invoking `create-pr`. Do not pass `head` and `base` at the workflow level.

**Output:** `{ url: string, number?: integer, fallback?: boolean }`

`url` is the only field guaranteed by the promote-branch scripts today. `number` is optional when the caller can derive it. If no PAT is available, the operation should set `fallback: true` and print the PR comparison URL for manual creation in the browser.

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

### `wait-for-pr-merge`

Block workflow execution until a story PR is merged. Prompts the user to merge,
then polls for merge status. Stops the workflow if the PR is not merged within the timeout.

**Algorithm:**
```bash
# Inputs: repo_path, source_branch, target_branch, pr_url, timeout_seconds (default: 300)

output: |
  ⏳ Story PR Merge Gate
  ├── PR: ${pr_url}
  ├── Branch: ${source_branch} → ${target_branch}
  └── ⚠️  Please merge this PR now. Waiting up to 5 minutes...

# Poll every 30 seconds for merge status
elapsed=0
interval=30
while [ $elapsed -lt ${timeout_seconds} ]; do
  pr_status=$(invoke: git-orchestration.query-pr-status
    params:
      source_branch: "${source_branch}"
      target_branch: "${target_branch}"
      repo_path: "${repo_path}")

  if pr_status.state == "merged":
    output: |
      ✅ Story PR merged!
      ├── PR: ${pr_url}
      ├── Merged at: ${pr_status.merged_at}
      └── Continuing to next story...
    return { merged: true, merged_at: pr_status.merged_at }

  sleep ${interval}
  elapsed=$((elapsed + interval))
  remaining=$((timeout_seconds - elapsed))
  output: "⏳ PR not yet merged. ${remaining}s remaining..."
done

# Timeout reached — PR not merged
output: |
  ❌ PR Merge Timeout
  ├── PR: ${pr_url}
  ├── Waited: ${timeout_seconds}s
  └── STOPPING — merge the PR and re-run /dev to continue.
return { merged: false, timed_out: true }
```

**Input:**
```yaml
repo_path: "${target_path}"
source_branch: "feature/epic-1-1-1-user-auth"
target_branch: "feature/epic-1"
pr_url: "https://github.com/org/repo/pull/42"
timeout_seconds: 300
```

**Output:** `{ merged: boolean, merged_at: string | null, timed_out: boolean }`

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

## Target Project Branch Management

Target project repos (code repos, not lens-work control repo) follow the GitFlow branching
model defined in `lifecycle.yaml → target_projects`. This section formalizes the automation
for epic branches, story branches, task auto-commits, and story-completion PRs.

### Branch Naming Contract

```yaml
# Epic branch:  feature/{epic-key}
# Story branch: feature/{epic-key}-{story-key}
#
# Branch Hierarchy:
#   Initiative: feature/{initiative_id}
#   Epic:      feature/{initiative_id}-{epic_key}
#   Story:     feature/{initiative_id}-{epic_key}-{story_key}
#
# Stories chain: story-2 branches off story-1 (not off epic).
# PRs are created per story (story→epic) but execution continues without waiting.
# Hard stop occurs per EPIC (epic→initiative PR merge gate).
#
# {initiative_id} — from initiative config (initiative.id, e.g., "lens", "core")
# {epic_key}     — from sprint-status.yaml (e.g., "epic-1", "epic-2")
# {story_key}    — from sprint-status.yaml (e.g., "1-1-user-authentication")
```

### `ensure-initiative-branch`

Ensure the initiative branch exists in target repo. Creates from integration branch if missing.
The initiative branch is the merge target for all epic branches in this initiative.

**Algorithm:**
```bash
initiative_branch="feature/${initiative_id}"

cd "${target_repo_path}"
git fetch origin
if ! git rev-parse --verify "origin/${initiative_branch}" > /dev/null 2>&1; then
  # Initiative branch does not exist — create from integration branch
  # Fallback chain: develop → main → master → FAIL
  integration_branch=""
  for candidate in develop main master; do
    if git rev-parse --verify "origin/${candidate}" > /dev/null 2>&1; then
      integration_branch="${candidate}"
      break
    fi
  done
  if [[ -z "${integration_branch}" ]]; then
    echo "❌ FAIL: No integration branch found (tried develop, main, master)"
    exit 1
  fi
  git checkout "${integration_branch}"
  git pull origin "${integration_branch}"
  git checkout -b "${initiative_branch}"
  git push origin "${initiative_branch}"
  echo "✅ Created initiative branch: ${initiative_branch} from ${integration_branch}"
  # Store resolved integration branch for initiative→integration PR targeting
  echo "${integration_branch}" > .lens-work-integration-branch
else
  echo "✅ Initiative branch exists: ${initiative_branch}"
  # Resolve what integration branch the initiative was created from
  for candidate in develop main master; do
    if git rev-parse --verify "origin/${candidate}" > /dev/null 2>&1; then
      echo "${candidate}" > .lens-work-integration-branch
      break
    fi
  done
  git checkout "${initiative_branch}"
  git pull origin "${initiative_branch}"
  echo "✅ Initiative branch synced: ${initiative_branch}"
fi
```

**Input:**
```yaml
target_repo_path: "${target_path}"
initiative_id: "lens"
```

---

### `ensure-epic-branch`

Ensure parent epic branch exists in target repo. Creates from the **initiative branch** (not directly from integration).

**Algorithm:**
```bash
epic_branch="feature/${initiative_id}-${epic_key}"
initiative_branch="feature/${initiative_id}"

cd "${target_repo_path}"
git fetch origin
if ! git rev-parse --verify "origin/${epic_branch}" > /dev/null 2>&1; then
  # Epic branch does not exist — create from initiative branch
  git checkout "${initiative_branch}"
  git pull origin "${initiative_branch}"
  git checkout -b "${epic_branch}"
  git push origin "${epic_branch}"
  echo "✅ Created epic branch: ${epic_branch} from ${initiative_branch}"
else
  echo "✅ Epic branch exists: ${epic_branch}"
  # Pull latest on epic branch to pick up any previously merged story PRs
  git checkout "${epic_branch}"
  git pull origin "${epic_branch}"
  echo "✅ Epic branch synced: ${epic_branch}"
fi
```

**Input:**
```yaml
target_repo_path: "${target_path}"
initiative_id: "lens"
epic_key: "epic-1"
epic_branch: "feature/lens-epic-1"
initiative_branch: "feature/lens"
```

---

### `ensure-story-branch`

Ensure story branch exists in target repo.
**Chaining:** The FIRST story in an epic branches from the epic branch.
Subsequent stories branch from the PREVIOUS story branch (story chaining).
**HARD ASSERTION:** After this operation completes, the current branch MUST be the story branch.
If `git branch --show-current` does not return the story branch name, FAIL immediately.

**Algorithm:**
```bash
story_branch="feature/${initiative_id}-${epic_key}-${story_key}"

cd "${target_repo_path}"
git fetch origin
if ! git rev-parse --verify "origin/${story_branch}" > /dev/null 2>&1; then
  # Story branch does not exist — create from parent branch
  # parent_branch is either the epic branch (first story) or previous story branch (chained)
  git checkout "${parent_branch}"
  git pull origin "${parent_branch}"
  git checkout -b "${story_branch}"
  git push origin "${story_branch}"
  echo "✅ Created story branch: ${story_branch} from ${parent_branch}"
else
  # Story branch already exists — checkout and pull latest
  git checkout "${story_branch}"
  git pull origin "${story_branch}"
  echo "✅ Resumed story branch: ${story_branch}"
fi

# === HARD ASSERTION — Verify checkout succeeded ===
actual_branch=$(git branch --show-current)
if [[ "${actual_branch}" != "${story_branch}" ]]; then
  echo "❌ FAIL: Story branch checkout failed"
  echo "├── Expected: ${story_branch}"
  echo "├── Actual:   ${actual_branch}"
  echo "└── All implementation MUST happen on the story branch, never on epic or integration"
  exit 1
fi
echo "✅ Verified: working on story branch ${story_branch}"
```

**Input (first story):**
```yaml
target_repo_path: "${target_path}"
initiative_id: "lens"
epic_key: "epic-1"
story_key: "1-1-user-authentication"
story_branch: "feature/lens-epic-1-1-1-user-authentication"
parent_branch: "feature/lens-epic-1"   # first story → branches from epic
```

**Input (chained story):**
```yaml
target_repo_path: "${target_path}"
initiative_id: "lens"
epic_key: "epic-1"
story_key: "1-2-profile-management"
story_branch: "feature/lens-epic-1-1-2-profile-management"
parent_branch: "feature/lens-epic-1-1-1-user-authentication"   # chains off story 1
```

---

### Task Auto-Commit

Every completed task MUST be committed and pushed immediately.
All git operations MUST run from inside `session.target_path` — never from the control repo or workspace root.

**Pre-Commit Guards (HARD ERRORS):**
1. Working directory MUST be inside `session.target_path`
2. Current branch MUST be the story branch — NEVER the epic branch or integration branch
3. Commits directly to `feature/{epic-key}` (without story suffix) are BLOCKED

**Algorithm:**
```bash
# Guard 1: Ensure we are inside the target repo — HARD ERROR if not
cd "${target_repo_path}" || FAIL("❌ Cannot cd to target repo: ${target_repo_path}")
actual_dir=$(pwd)
if [[ "${actual_dir}" != *"${target_repo_path}"* ]]; then
  FAIL("❌ Working directory mismatch — expected inside ${target_repo_path}, got ${actual_dir}")
fi

# Guard 2: Verify current branch is the STORY branch, not epic or integration
current_branch=$(git branch --show-current)
if [[ "${current_branch}" != "${story_branch}" ]]; then
  echo "❌ FAIL: Task commit blocked — wrong branch"
  echo "├── Expected (story branch): ${story_branch}"
  echo "├── Actual branch:           ${current_branch}"
  echo "├── Commits MUST go to the story branch, never epic or integration"
  echo "└── Run: git checkout ${story_branch}"
  exit 1
fi

# Guard 3: Reject commits directly to epic branch pattern (feature/{initiativeId}-epic-N without story suffix)
if [[ "${current_branch}" =~ ^feature/[a-zA-Z0-9_-]+-epic-[0-9]+$ ]]; then
  echo "❌ FAIL: Direct commit to epic branch BLOCKED"
  echo "├── Current: ${current_branch}"
  echo "├── Epic branches receive code ONLY via story→epic PR merges"
  echo "└── Checkout the story branch: git checkout ${story_branch}"
  exit 1
fi

git add -A
git commit -m "feat(${story_key}): ${task_description}

Story: ${story_key}
Task: ${task_number}/${total_tasks}
Epic: ${epic_key}"
git push origin "${story_branch}"
echo "✅ Task ${task_number}/${total_tasks} committed and pushed to ${story_branch}"
```

**Commit message convention:**
- Line 1: `feat({story-key}): {task summary}`
- Body: Story key, task progress, epic key
- Auto-push: ALWAYS (per git_discipline.auto_push convention)

---

### Story Completion PR

When ALL tasks in a story are complete, auto-create a PR from story branch to epic branch.

**Pre-PR Guards (HARD ERRORS):**
1. Current branch MUST be the story branch
2. Story branch MUST have commits that differ from epic branch (non-empty diff)
3. If no diff exists, the PR is meaningless — investigate why commits went to wrong branch

**Algorithm:**
```bash
cd "${target_repo_path}"

# Guard 1: Verify on story branch
current_branch=$(git branch --show-current)
if [[ "${current_branch}" != "${story_branch}" ]]; then
  echo "❌ FAIL: Cannot create story PR — not on story branch"
  echo "├── Expected: ${story_branch}"
  echo "├── Actual:   ${current_branch}"
  exit 1
fi

# Ensure all changes are committed and pushed
git add -A
if ! git diff --cached --quiet; then
  git commit -m "feat(${story_key}): story complete — all tasks done"
  git push origin "${story_branch}"
fi

# Guard 2: Non-empty diff check — story branch MUST have changes vs epic branch
diff_count=$(git log "${epic_branch}..${story_branch}" --oneline | wc -l | tr -d ' ')
if [[ "${diff_count}" -eq 0 ]]; then
  echo "❌ FAIL: Story branch has NO commits ahead of epic branch"
  echo "├── Story: ${story_branch}"
  echo "├── Epic:  ${epic_branch}"
  echo "├── Diff:  0 commits"
  echo "├── This means either:"
  echo "│   1. Tasks were committed to the epic branch directly (WRONG)"
  echo "│   2. The story branch was never checked out before committing"
  echo "│   3. A previous merge already included these changes"
  echo "└── INVESTIGATE: run 'git log --oneline ${epic_branch}' to find misplaced commits"
  exit 1
fi
echo "✅ Story branch has ${diff_count} commit(s) ahead of epic — PR will have content"

# Create PR via create-pr operation
# See create-pr operation for full details
```

**PR Naming Convention:**
- Title: `feat({epic-key}): {story-title} [{story-key}]`
- Body: Story summary, acceptance criteria, completed tasks, files changed

---

### Epic Completion PR

When all stories in an epic are complete, auto-create a PR from epic branch → **initiative branch**.
The epic does NOT merge into develop/main/master directly — it merges into the initiative branch.

**Algorithm:**
```bash
epic_branch="feature/${initiative_id}-${epic_key}"
initiative_branch="feature/${initiative_id}"

cd "${target_repo_path}"
echo "Epic PR target: ${epic_branch} → ${initiative_branch}"

# Create PR from epic branch to initiative branch
# See create-pr operation for full details
```

---

### Initiative Completion PR (Optional)

When all epics in an initiative are complete, create PR from initiative branch → integration branch.
This is typically triggered manually or by a higher-level workflow after all epics are merged.

**Algorithm:**
```bash
initiative_branch="feature/${initiative_id}"

cd "${target_repo_path}"

# Read the resolved integration branch
if [[ -f .lens-work-integration-branch ]]; then
  integration_branch=$(cat .lens-work-integration-branch)
else
  for candidate in develop main master; do
    if git rev-parse --verify "origin/${candidate}" > /dev/null 2>&1; then
      integration_branch="${candidate}"
      break
    fi
  done
  if [[ -z "${integration_branch}" ]]; then
    echo "❌ FAIL: No integration branch found for initiative PR target"
    exit 1
  fi
fi

echo "Initiative PR target: ${initiative_branch} → ${integration_branch}"
# Create PR from initiative branch to integration branch
```

**CRITICAL:** The `base` branch for the epic PR MUST be `session.resolved_integration_branch`
(the actual branch the epic was created from), NOT a hardcoded `default_branch` value.
If the target repo uses `master` as its default, the epic PR targets `master`.

**PR Naming Convention:**
- Title: `feat({epic-key}): Epic complete — {epic-title}`
- Body: Epic summary, list of completed stories

---

## Multi-Developer Parallel Development

When multiple developers (human or AI agents) work on the same initiative simultaneously,
the epic-branch topology provides structural isolation.

### Branch Isolation Model

```
develop (integration)
├── feature/epic-1   ← Dev A
│   ├── feature/epic-1-1-1-api-camelcase
│   └── feature/epic-1-1-5-benchmark-selector
├── feature/epic-2   ← Dev B
│   ├── feature/epic-2-2-1-dataentry-autosave
│   └── feature/epic-2-2-5-closeout-routes
└── feature/epic-3   ← Dev C
    └── feature/epic-3-3-1-linegraph-recharts
```

**Key principle:** Each developer works on their own epic branch. Story branches are children
of the epic branch. Two developers on different epics have **zero branch overlap**.

### Coordination Rules

1. **One developer per epic** — Each epic should be assigned to a single developer at a time.
2. **Pull control repo before claiming** — Always `git pull` before claiming a story.
3. **Commit and push sprint-status immediately** — After claiming a story, commit and push so other developers see the claim.
4. **Route-removal stories must merge sequentially** — Stories that remove routes from shared files across multiple epics should be the LAST stories in each epic, and their epic-completion PRs should be merged one at a time.
5. **Shared file conflict zones** — When two epics both modify the same file, add explicit Dev Notes documenting which sections each touches.

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
| Outside `session.target_path` during `/dev` | Blocked — dev writes scoped to target repo only | `❌ BLOCK — /dev writes MUST be within target repo: {session.target_path}. Attempted: {path}` |

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
  # Dev Write Guard: /dev phase scopes ALL file writes to the target repo
  if context == "dev-implementation":
    target_abs = resolve_absolute(session.target_path)
    file_abs = resolve_absolute(path)
    if file_abs is NOT under target_abs:
      HARD ERROR — /dev writes MUST be within target repo
        ├── Allowed scope: ${session.target_path}
        ├── Attempted path: ${path}
        └── Domain/service: ${initiative.docs.domain}/${initiative.docs.service}
  return ALLOWED
```

### Dev Write Guard — `/dev` Phase Scope Enforcement

During the `/dev` phase, **ALL implementation file writes** (file creation, modification, deletion,
`git add`, `git commit`) are restricted to the target repo folder at `session.target_path`.

This path is resolved from `initiative.target_repos[0].local_path` during Pre-Flight.

**Allowed during `/dev`:**
- File writes inside `session.target_path` (the target repo)
- Control repo state updates in `_bmad-output/` (sprint-status, initiative config)

**Blocked during `/dev`:**
- Writes to any repo folder other than `session.target_path`
- Writes to `bmad.lens.release/`, governance repo, `.github/`
- Writes to other target repos not selected for this initiative

### Exception: Governance PR Proposals

@lens MAY propose a governance PR (submit PR to governance repo) but cannot directly write files there. The proposal flow creates a PR in the governance repo for human review.

## Dependencies

- `lifecycle.yaml` — for branch naming patterns, valid phases, valid audiences
- Provider adapter — for PR merge state verification before branch cleanup
- `git-state` skill — for reading current state before write operations
