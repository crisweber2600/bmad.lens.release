# Story Target Repo Routing

Use this reference inside the active story loop in `steps/step-03-story-loop.md`.

## Initiative, Epic, And Story Branch Management

```yaml
story_key = story_id
epic_num = session.epic_number
epic_key = "epic-${epic_num}"

initiative_id = initiative.id || "init-1"
session.initiative_id = initiative_id

initiative_branch = "feature/${initiative_id}"
epic_branch = "feature/${initiative_id}-${epic_key}"
story_branch = "feature/${initiative_id}-${epic_key}-${story_key}"

target_path = session.target_path
target_repo = session.target_repo

cd "${target_path}"
git fetch origin
default_branch_check = exec("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo ''")
if default_branch_check == '':
  for candidate in ["develop", "main", "master"]:
    if exec("git rev-parse --verify origin/${candidate} 2>/dev/null").exit_code == 0:
      default_branch_check = candidate
      break
git checkout "${default_branch_check}"
git pull origin "${default_branch_check}"
output: |
  🔄 Target repo synced - pulled latest from ${default_branch_check}
  └── Path: ${target_path}

invoke: git-orchestration.ensure-initiative-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"

invoke: git-orchestration.ensure-epic-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"
  epic_key: "${epic_key}"
  epic_branch: "${epic_branch}"
  initiative_branch: "${initiative_branch}"

if story_idx == 0:
  parent_branch = epic_branch
else:
  prev_story_id = extract_story_id(session.story_files[story_idx - 1])
  parent_branch = "feature/${initiative_id}-${epic_key}-${prev_story_id}"

invoke: git-orchestration.ensure-story-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"
  epic_key: "${epic_key}"
  story_key: "${story_key}"
  story_branch: "${story_branch}"
  parent_branch: "${parent_branch}"

session.initiative_id = "${initiative_id}"
session.initiative_branch = "${initiative_branch}"
session.epic_key = "${epic_key}"
session.epic_branch = "${epic_branch}"
session.story_branch = "${story_branch}"

resolved_ib_file = "${target_path}/.lens-work-integration-branch"
if file_exists(resolved_ib_file):
  session.resolved_integration_branch = read_file(resolved_ib_file).trim()
else:
  session.resolved_integration_branch = target_repo.default_branch || "develop"

actual_branch = exec("git -C ${target_path} branch --show-current").stdout.trim()
if actual_branch != story_branch:
  FAIL: |
    ❌ Branch checkout assertion failed after ensure-story-branch
    ├── Expected: ${story_branch}
    ├── Actual:   ${actual_branch}
    ├── All task commits MUST go to the story branch
    └── Epic branch receives code ONLY via story->epic PR merges

output: |
  📂 Target Repo Ready - ALL implementation goes here (NOT bmad.lens.release)
  ├── Repo: ${target_repo.name}
  ├── Path: ${target_path}
  ├── Initiative: ${initiative_id}
  ├── Initiative Branch: ${initiative_branch}
  ├── Epic Branch: ${epic_branch}
  ├── Story Branch: ${story_branch} (checked out ✅ VERIFIED)
  ├── Parent Branch: ${parent_branch} (${story_idx == 0 ? 'from epic' : 'chained from prev story'})
  ├── Branch Chain: ${story_branch} -> ${epic_branch} -> ${initiative_branch} -> ${session.resolved_integration_branch}
  ├── Auto-commit: ON (tasks auto-committed after completion)
  ├── Auto-PR: ON (PR created after code review, no wait)
  ├── ⚠️  Commits go to STORY branch only - epic branch is merge-only
  └── ⚠️  bmad.lens.release is READ-ONLY - never write there
```

## Dev Write Guard

```yaml
cd "${session.target_path}"
actual_dir = exec("pwd").stdout.trim()

target_canonical = canonicalize(session.target_path)
actual_canonical = canonicalize(actual_dir)

if actual_canonical contains "bmad.lens.release":
  FAIL: |
    ❌ Dev Write Guard - BLOCKED: Working directory is inside bmad.lens.release
    ├── Actual: ${actual_dir}
    ├── bmad.lens.release is a READ-ONLY authority repo
    ├── It contains BMAD framework code, NOT implementation targets
    └── Implementation MUST happen in: ${session.target_path}

if actual_canonical does not start with target_canonical:
  FAIL: |
    ❌ Dev Write Guard - Working directory mismatch
    ├── Expected: ${session.target_path}
    ├── Actual: ${actual_dir}
    └── All /dev implementation writes MUST be inside the TargetProject repo.

output: |
  🔒 Dev Write Guard - PASSED
  ├── Working directory: ${actual_dir}
  ├── Scoped to TargetProject repo: ${session.target_path}
  └── ⚠️  bmad.lens.release is READ-ONLY - never write there
```