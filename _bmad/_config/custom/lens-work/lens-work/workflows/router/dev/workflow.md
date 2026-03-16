---
name: dev
description: Epic-level implementation loop (story development/per-task commits/code-review/retro)
agent: "@lens"
trigger: /dev command
category: router
phase: dev
phase_name: Dev
inputs:
  epic_number:
    description: Epic number to implement (required)
    required: true
  special_instructions:
    description: Optional freeform guidance applied to ALL story implementations
    required: false
    default: ""
---

# /dev — Implementation Phase Router (Epic-Level Loop)

**Purpose:** Iterate all stories in an epic, implementing each with per-task commits, adversarial code review after each story (with fix loop), epic-completion teardown, and retrospective.

---

## Role Authorization

**Authorized:** Developer (post-review only)

---

## Prerequisites

- [x] `/sprintplan` complete (large → base promotion passed)
- [x] Dev stories exist for the target epic (created by `/sprintplan`)
- [x] Epic number provided as input parameter
- [x] Developer assigned (or self-assigned)
- [x] initiatives/{id}.yaml exists
- [x] Constitution gate passed (large → base audience promotion)

---

## Execution Sequence

### 0. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 1. Verify working directory is clean
# 2. Load initiative config (git-derived state)
# 3. Check previous phase status (if applicable)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to artifact work

# Verify working directory is clean
invoke: git-orchestration.verify-clean-state

# Load initiative config from current git branch (v2 git-derived state)
branch = invoke: git-orchestration.get-current-branch
initiative = load("_bmad-output/lens-work/initiatives/${git-state.parse-initiative-root(branch)}.yaml")

# Read initiative config
size = initiative.size
domain_prefix = initiative.domain_prefix

# Derive audience for dev phase (base) [REQ-9]
audience = "base"
initiative_root = initiative.initiative_root
audience_branch = "base"

# === Path Resolver (S01-S06: Context Enhancement) ===
docs_path = initiative.docs.path
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."
  warning: "  → Run: /lens migrate <initiative-id> to add docs.path"

# NOTE: docs_path is READ-ONLY in /dev — used for context loading (S11)
# Dev outputs go to _bmad-output/implementation-artifacts/ (unchanged)

# REQ-10: Resolve BmadDocs path for per-initiative output co-location
bmad_docs = initiative.docs.bmad_docs

# === Target Repo Validation Gate ===
# /dev must only operate against repos registered in the initiative.
# If target_repos is missing or empty, ask the user before proceeding.
if initiative.target_repos == null or initiative.target_repos.length == 0:
  output: |
    ⚠️ No target repos configured for this initiative.
    ├── Initiative: ${initiative.id}
    └── target_repos field is missing or empty.

  ask: |
    Please provide the path to the target repo for this initiative.
    This should be the local path to the repository (e.g., TargetProjects/domain/service/repo-name):
  capture: user_target_path

  if user_target_path == null or user_target_path == "":
    FAIL("❌ Target repo path is required for /dev. Cannot proceed without a target repo.")

  # Use the user-provided path as a single target repo entry
  session.target_repo = { name: basename(user_target_path), local_path: user_target_path }
  session.target_path = user_target_path
  warning: |
    ⚠️ Using user-provided target path: ${user_target_path}
    Consider running /lens init-repo to register this repo in the initiative config.
else:
  # Use the first registered target repo from the initiative
  session.target_repo = initiative.target_repos[0]
  session.target_path = initiative.target_repos[0].local_path

output: |
  📂 Target Repo Resolved
  ├── Repo: ${session.target_repo.name}
  └── Path: ${session.target_path}

# === HARD REJECTION: bmad.lens.release is NEVER a valid implementation target ===
# The target_path MUST point to a TargetProject repo, never the release framework repo.
if session.target_path contains "bmad.lens.release":
  FAIL: |
    ❌ INVALID TARGET — bmad.lens.release is a READ-ONLY authority repo.
    ├── Resolved target_path: ${session.target_path}
    ├── bmad.lens.release contains BMAD framework code (agents, workflows, lifecycle)
    ├── It is NEVER the implementation target for /dev
    └── Fix: Update initiative.target_repos to point to the actual TargetProject repo path.
    
    Expected target_path pattern: TargetProjects/{domain}/{service}/{repo-name}

# === Context Loader (S11: Context Enhancement) ===
if docs_path != "_bmad-output/planning-artifacts/":
  architecture = load_if_exists("${docs_path}/architecture.md")
  stories = load_if_exists("${docs_path}/stories.md")
  planning_context = { architecture: architecture, stories: stories }
else:
  planning_context = null

# REQ-7/REQ-9: Validate previous phase (sprintplan) and audience promotion
prev_phase = "sprintplan"
prev_audience = "large"
prev_phase_branch = "${initiative.initiative_root}-${prev_audience}-sprintplan"
prev_audience_branch = "${initiative.initiative_root}-${prev_audience}"

if initiative.phase_status[prev_phase] exists:
  if initiative.phase_status[prev_phase] == "pr_pending":
    branch_exists_result = git-orchestration.exec("git ls-remote --heads origin ${prev_audience_branch}")
    prev_audience_branch_exists = (branch_exists_result.stdout != "")

    if prev_audience_branch_exists:
      result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_phase_branch} origin/${prev_audience_branch}")

      if result.exit_code == 0:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) PR merged — status updated to complete"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Previous phase (sprintplan) PR not yet merged
          ├── Status: pr_pending
          ├── PR: ${pr_url}
          └── You may continue, but phase artifacts may not be on the audience branch

        ask: "Continue anyway? [Y]es / [N]o"
        if no:
          exit: 0
    else:
      if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) complete — audience branch merged and deleted (large→base promotion passed)"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Audience branch ${prev_audience_branch} not found remotely
          ├── May have been deleted after PR merge
          ├── PR: ${pr_url}
          └── Proceeding — verify manually if needed

# Dev stories are discovered per-epic in Step 2 — no single story check needed here
# Batch mode still supported for question-only runs
if initiative.question_mode == "batch":
  # handled in Step 1c
  pass

# Audience validation — verify large→base promotion passed
if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Audience promotion validation pending
    ├── Required: large → base promotion (constitution gate)
    └── ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0

# Determine phase branch [REQ-9]
phase_branch = "${initiative.initiative_root}-dev"

# Step 5: Create phase branch if it doesn't exist [REQ-9]
if not branch_exists(phase_branch):
  invoke: git-orchestration.start-phase
  params:
    phase_name: "dev"
    initiative_id: ${initiative.id}
    audience: ${audience}
    initiative_root: ${initiative.initiative_root}
    parent_branch: ${audience_branch}
  if start_phase.exit_code != 0:
    FAIL("❌ Pre-flight failed: Could not create branch ${phase_branch}")

# Step 6: Checkout phase branch
invoke: git-orchestration.checkout-branch
params:
  branch: ${phase_branch}
invoke: git-orchestration.pull-latest

# Step 7: Confirm to user
output: |
  📋 Pre-flight complete [REQ-9]
  ├── Initiative: ${initiative.name} (${initiative.id})
  ├── Phase: Dev (Implementation)
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 1. Audience Promotion Check — large → base Complete

```yaml
# Verify large→base audience promotion gate passed (constitution gate)
sprintplan_branch = "${initiative.initiative_root}-large-sprintplan"
large_branch = "${initiative.initiative_root}-large"

sprintplan_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${sprintplan_branch}").stdout != ""
large_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${large_branch}").stdout != ""

if sprintplan_branch_exists and large_branch_exists:
  result = git-orchestration.exec("git merge-base --is-ancestor origin/${sprintplan_branch} origin/${large_branch}")

  if result.exit_code != 0:
    error: |
      ❌ Merge gate blocked
      ├── SprintPlan not merged into large audience branch
      ├── Expected: ${sprintplan_branch} is ancestor of ${large_branch}
      └── Action: Complete /sprintplan and merge PR first
else:
  if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
    output: "✅ Audience branch(es) deleted post-merge — large→base promotion already complete"
  else:
    output: |
      ⚠️  Audience branch(es) not found remotely
      ├── sprintplan: ${sprintplan_branch} (${sprintplan_branch_exists ? 'found' : 'gone'})
      ├── large: ${large_branch} (${large_branch_exists ? 'found' : 'gone'})
      └── Proceeding — verify manually if needed

if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Constitution gate still not passed for large → base
    ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0
```

### 1a. Constitutional Context Injection (Required)

```yaml
constitutional_context = invoke("constitution.resolve-context")

if constitutional_context.status == "parse_error":
  error: |
    Constitutional context parse error:
    ${constitutional_context.error_details.file}
    ${constitutional_context.error_details.error}

session.constitutional_context = constitutional_context
```

### 1b. Branch Verification (consolidated into Pre-Flight)

```yaml
assert: current_branch == phase_branch
```

### 1c. Batch Mode (Single-File Questions)

```yaml
if initiative.question_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "dev"
    template_path: "templates/phase-4-implementation-questions.template.md"
    output_filename: "dev-implementation-questions.md"
  exit: 0
```

### 2. Epic Story Discovery

```yaml
# Input: epic_number (from prompt parameters)
epic_number = params.epic_number
special_instructions = params.special_instructions || ""
session.special_instructions = special_instructions

# Discover all story files for this epic
# Search order: BmadDocs first, then legacy location
story_files = []

if bmad_docs != null:
  story_files += glob("${bmad_docs}/dev-story-${epic_number}-*.md")
  story_files += glob("${bmad_docs}/*epic-${epic_number}*.md")

story_files += glob("_bmad-output/implementation-artifacts/dev-story-${epic_number}-*.md")
story_files += glob("_bmad-output/implementation-artifacts/*epic-${epic_number}*.md")

# Deduplicate (prefer BmadDocs version if same story exists in both)
story_files = deduplicate_by_story_id(story_files)

# Sort by story number within epic (e.g., 1-1, 1-2, 1-3)
story_files = sort_by_story_order(story_files)

if story_files.length == 0:
  error: |
    ❌ No story files found for epic ${epic_number}.
    Searched:
    ├── ${bmad_docs}/dev-story-${epic_number}-*.md
    ├── ${bmad_docs}/*epic-${epic_number}*.md
    ├── _bmad-output/implementation-artifacts/dev-story-${epic_number}-*.md
    └── _bmad-output/implementation-artifacts/*epic-${epic_number}*.md
    Run /sprintplan to create dev stories first.
  exit: 1

output: |
  🚀 /dev — Epic ${epic_number} Implementation
  
  📋 Stories discovered: ${story_files.length}
  ${for idx, file in enumerate(story_files)}
  ${idx + 1}. ${extract_story_title(file)} — ${file}
  ${endfor}

  ${if special_instructions}
  📝 Special Instructions (applied to ALL stories):
  ${special_instructions}
  ${endif}

ask: "Proceed with implementing all ${story_files.length} stories? [Y]es / [N]o"
if no:
  exit: 0

# Track progress across the epic
session.epic_number = epic_number
session.story_files = story_files
session.stories_completed = []
session.stories_failed = []
```

### 2-LOOP. Story Implementation Loop

**For each story in the epic, execute Steps 2.N through 5.N before moving to the next story.**

```yaml
for story_idx, story_file in enumerate(session.story_files):
  story_id = extract_story_id(story_file)
  
  output: |
    ═══════════════════════════════════════════
    📖 Story ${story_idx + 1}/${session.story_files.length}: ${story_id}
    ═══════════════════════════════════════════
```

#### 2.N. Load Story

```yaml
  # Load the story file for this initiative
  dev_story = load(story_file)
  dev_story_source = story_file
  id = story_id

  output: |
    🚀 Story: ${dev_story.title}
    **Source:** ${dev_story_source}
    **Acceptance Criteria:**
    ${dev_story.acceptance_criteria}
    
    **Technical Notes:**
    ${dev_story.technical_notes}
    
    **Branch:** ${initiative.initiative_root}-dev
```

#### 2.Na. Story Constitution Check (Required)

```yaml
dev_story_path = dev_story_source

dev_story_compliance = invoke("constitution.compliance-check")
params:
  artifact_path: ${dev_story_path}
  artifact_type: "Story/Epic"
  constitutional_context: ${constitutional_context}

if dev_story_compliance.article_gate_results.failed_gates > 0:
  display: dev_story_compliance.article_gate_results

  if enforcement_mode == "enforced":
    invoke: constitution.auto-resolve-gate-block
    params:
      failed_gates: ${dev_story_compliance.article_gate_results}
      artifact_path: ${dev_story_path}
      artifact_type: "Story/Epic"
      initiative_id: ${initiative.id}
      source_branch: current_branch()
      gate_stage: "dev-story-compliance"
    halt: true
  else:
    warning: |
      ⚠️ Dev story has ${dev_story_compliance.article_gate_results.failed_gates} article gate warning(s).
    invoke: constitution.record-complexity-tracking
    params:
      article_gate_results: ${dev_story_compliance.article_gate_results}
      initiative_id: ${initiative.id}
      phase: "dev"

if dev_story_compliance.fail_count > 0 and enforcement_mode == "enforced":
  invoke: constitution.auto-resolve-gate-block
  params:
    fail_count: ${dev_story_compliance.fail_count}
    artifact_path: ${dev_story_path}
    artifact_type: "Story/Epic"
    initiative_id: ${initiative.id}
    source_branch: current_branch()
    gate_stage: "dev-story-compliance-legacy"
  halt: true
```

#### 2.Nb. Pre-Implementation Gates (Required)

```yaml
article_gates = invoke("constitution.generate-article-gates")
params:
  constitutional_context: ${constitutional_context}
  artifact_path: ${dev_story_path}
  artifact_type: "Story/Epic"

output: |
  ═══ Pre-Implementation Gates ═══
  ${for gate in article_gates.gates}
  Gate ${gate.article_id}: ${gate.title} (${gate.source_layer})  ${gate.status == "pass" ? "✓ PASS" : "✗ FAIL"}
    ${for item in gate.check_items}
    ${item.status == "pass" ? "✓" : "✗"} ${item.description}
      ${if item.status == "fail"}→ ${item.violation}${endif}
    ${endfor}
  ${endfor}
  ── Summary ──
    Passed: ${article_gates.passed_gates}/${article_gates.total_gates} gates
    Mode: ${enforcement_mode}

if article_gates.failed_gates > 0:
  if enforcement_mode == "enforced":
    invoke: constitution.auto-resolve-gate-block
    params:
      failed_gates: ${article_gates}
      artifact_path: ${dev_story_path}
      artifact_type: "Story/Epic"
      initiative_id: ${initiative.id}
      source_branch: current_branch()
      gate_stage: "pre-implementation-gates"
    halt: true
  else:
    output: |
      ⚠️ ${article_gates.failed_gates} gate(s) have warnings (advisory mode).
    for gate in article_gates.gates where gate.status == "fail":
      ask: |
        Override gate ${gate.article_id}: ${gate.title}?
        Provide justification and simpler alternative considered:
      invoke: constitution.record-complexity-tracking
      params:
        gate: ${gate}
        initiative_id: ${initiative.id}
        phase: "dev"
        justification: ${user_justification}

# Run checklist quality gate (skill Part 12)
checklist_gate = invoke("constitution.checklist-quality-gate")
params:
  bmad_docs: ${bmad_docs}
  docs_path: ${docs_path}
  initiative_id: ${initiative.id}
```

#### 3.N. Checkout Target Repo — Initiative, Epic & Story Branch Management

**IMPORTANT:** This is where we switch from BMAD control repo to TargetProjects.

**Branch hierarchy:** `feature/{initiativeId}` → `feature/{initiativeId}-{epic}` → `feature/{initiativeId}-{epic}-{story}`
**Story chaining:** Story 2 branches off story 1 (not off epic). Story 1 branches off epic.
**PR flow:** Story PRs are created (story→epic) but execution continues. Hard stop at epic level only.

```yaml
story_key = story_id
epic_num = session.epic_number
epic_key = "epic-${epic_num}"

# Resolve initiative_id from initiative config
initiative_id = initiative.id || "init-1"
session.initiative_id = initiative_id

# New branch naming convention
initiative_branch = "feature/${initiative_id}"
epic_branch = "feature/${initiative_id}-${epic_key}"
story_branch = "feature/${initiative_id}-${epic_key}-${story_key}"

# target_path resolved during Pre-Flight from initiative.target_repos
target_path = session.target_path
target_repo = session.target_repo

# --- Fresh Pull: Sync target repo default branch before any branching ---
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
  🔄 Target repo synced — pulled latest from ${default_branch_check}
  └── Path: ${target_path}

# --- Initiative Branch: Ensure initiative branch exists ---
invoke: git-orchestration.ensure-initiative-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"

# --- Epic Branch: Ensure epic branch exists (branches from initiative) ---
invoke: git-orchestration.ensure-epic-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"
  epic_key: "${epic_key}"
  epic_branch: "${epic_branch}"
  initiative_branch: "${initiative_branch}"

# --- Story Branch: Create or checkout story branch ---
# Story chaining: first story branches from epic, subsequent stories branch from previous story
if story_idx == 0:
  parent_branch = epic_branch
else:
  # Chain: branch from the previous story branch
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

# Read the resolved integration branch from ensure-initiative-branch
resolved_ib_file = "${target_path}/.lens-work-integration-branch"
if file_exists(resolved_ib_file):
  session.resolved_integration_branch = read_file(resolved_ib_file).trim()
else:
  session.resolved_integration_branch = target_repo.default_branch || "develop"

# === HARD ASSERTION — Verify agent is on the STORY branch, not epic ===
actual_branch = exec("git -C ${target_path} branch --show-current").stdout.trim()
if actual_branch != story_branch:
  FAIL: |
    ❌ Branch checkout assertion failed after ensure-story-branch
    ├── Expected: ${story_branch}
    ├── Actual:   ${actual_branch}
    ├── All task commits MUST go to the story branch
    └── Epic branch receives code ONLY via story→epic PR merges

output: |
  📂 Target Repo Ready — ALL implementation goes here (NOT bmad.lens.release)
  ├── Repo: ${target_repo.name}
  ├── Path: ${target_path}
  ├── Initiative: ${initiative_id}
  ├── Initiative Branch: ${initiative_branch}
  ├── Epic Branch: ${epic_branch}
  ├── Story Branch: ${story_branch} (checked out ✅ VERIFIED)
  ├── Parent Branch: ${parent_branch} (${story_idx == 0 ? 'from epic' : 'chained from prev story'})
  ├── Branch Chain: ${story_branch} → ${epic_branch} → ${initiative_branch} → ${session.resolved_integration_branch}
  ├── Auto-commit: ON (tasks auto-committed after completion)
  ├── Auto-PR: ON (PR created after code review, no wait)
  ├── ⚠️  Commits go to STORY branch only — epic branch is merge-only
  └── ⚠️  bmad.lens.release is READ-ONLY — never write there
```

#### 3.Nc. Verify Working Directory — Dev Write Guard

```yaml
# HARD GATE: Verify we are inside the TargetProject repo before implementation begins.
# bmad.lens.release is a READ-ONLY authority repo — NEVER the implementation target.
# The dev-write-guard in git-orchestration.md enforces that ALL /dev writes
# are scoped to session.target_path. This step ensures the working directory
# is set correctly before the agent starts implementing tasks.

cd "${session.target_path}"
actual_dir = exec("pwd").stdout.trim()

# Canonicalize paths for comparison (resolve symlinks, normalize separators)
target_canonical = canonicalize(session.target_path)
actual_canonical = canonicalize(actual_dir)

# Explicit rejection: if working directory is inside bmad.lens.release, HARD FAIL
if actual_canonical contains "bmad.lens.release":
  FAIL: |
    ❌ Dev Write Guard — BLOCKED: Working directory is inside bmad.lens.release
    ├── Actual: ${actual_dir}
    ├── bmad.lens.release is a READ-ONLY authority repo
    ├── It contains BMAD framework code, NOT implementation targets
    └── Implementation MUST happen in: ${session.target_path}

if actual_canonical does not start with target_canonical:
  FAIL: |
    ❌ Dev Write Guard — Working directory mismatch
    ├── Expected: ${session.target_path}
    ├── Actual: ${actual_dir}
    └── All /dev implementation writes MUST be inside the TargetProject repo.

output: |
  🔒 Dev Write Guard — PASSED
  ├── Working directory: ${actual_dir}
  ├── Scoped to TargetProject repo: ${session.target_path}
  └── ⚠️  bmad.lens.release is READ-ONLY — never write there
```

#### 4.N. Implementation Guidance + Constitutional Context + Special Instructions

```yaml
articles = constitutional_context.resolved.articles

tdd_articles = filter(articles, rule_text contains "test" or "TDD" or "test-first")
arch_articles = filter(articles, rule_text contains "simplicity" or "abstraction" or "library")
quality_articles = filter(articles, rule_text contains "observability" or "logging" or "coverage")
integration_articles = filter(articles, rule_text contains "integration" or "contract" or "mock")

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")
override_count = count_entries(complexity_tracking) if complexity_tracking else 0
```

```
🔧 Implementation Mode — Story ${story_idx + 1}/${session.story_files.length}

You're now working in: ${target_path}
⚠️  THIS is the TargetProject repo — NOT bmad.lens.release (which is read-only).

${if session.special_instructions}
═══ Special Instructions (User-Provided) ═══
${session.special_instructions}
══════════════════════════════════════════════
Apply these instructions to ALL implementation decisions for this story.
${endif}

═══ Constitutional Guidance ═══

${if tdd_articles}
🧪 Test-First Requirements:
${for article in tdd_articles}
  Article ${article.article_id}: ${article.title}
  → ${article.rule_text_summary}
${endfor}
  ⚡ Action: Write tests FIRST. Verify they FAIL. Then implement.
${endif}

${if arch_articles}
🏗️ Architecture Constraints:
${for article in arch_articles}
  Article ${article.article_id}: ${article.title}
  → ${article.rule_text_summary}
${endfor}
${endif}

${if quality_articles}
📊 Quality Requirements:
${for article in quality_articles}
  Article ${article.article_id}: ${article.title}
  → ${article.rule_text_summary}
${endfor}
${endif}

${if integration_articles}
🔗 Integration Rules:
${for article in integration_articles}
  Article ${article.article_id}: ${article.title}
  → ${article.rule_text_summary}
${endfor}
${endif}

${if override_count > 0}
⚠️ Active Overrides: ${override_count} complexity tracking entries
   Review: ${bmad_docs}/complexity-tracking.md
${endif}

═══════════════════════════════

**Per-Task Commit Rule:**
- BEFORE each commit, verify you are on the STORY branch:
  ```bash
  cd "${target_path}"
  current=$(git branch --show-current)
  if [[ "$current" != "${story_branch}" ]]; then
    echo "❌ BLOCKED: On branch $current, expected ${story_branch}"
    git checkout "${story_branch}"
  fi
  ```
- After completing EACH task/subtask, immediately commit and push:
  ```bash
  git add -A
  git commit -m "feat(${story_key}): {task-description}

  Story: ${story_key}
  Task: {task_number}/{total_tasks}
  Epic: ${epic_key}"
  git push origin "${story_branch}"
  ```
- Do NOT batch task commits — each task gets its own commit
- Commit body MUST include Story, Task, and Epic metadata
- Push target MUST specify `origin "${story_branch}"` — never bare `git push`
- NEVER commit directly to `${epic_branch}` — epic branch receives code ONLY via merged PRs

**Remember:**
- ALL file writes go to ${target_path} (the TargetProject repo) — NEVER to bmad.lens.release
- ALL commits go to the STORY branch — NEVER to the epic or integration branch
- Follow constitutional articles above during implementation
- Follow special instructions (if provided) for all implementation decisions
- Commit after EACH task (not after all tasks)
- Return to BMAD directory when story implementation is complete
```

```yaml
if article_gates and article_gates.failed_gates > 0 and enforcement_mode == "enforced":
  halt: true
  output: |
    ⛔ BLOCKED — Unresolved enforced gate failures detected at Step 4.N
    ├── ${article_gates.failed_gates} gate(s) still failing
    ├── Resolve violations and re-run /dev
    └── Implementation cannot proceed until all enforced gates pass
else:
  output: |
    ✅ No blockers — proceeding with story ${story_id} implementation
    ├── All pre-implementation gates passed
    ├── Agent will implement story tasks in the target repo
    ├── Each task will be committed individually
    └── Code review will run automatically after all tasks complete
```

**Agent Implementation Flow (Per-Task Commits):**
The agent implements each task in the story sequentially.
After completing EACH task:
1. `git add -A` in target repo
2. Commit with multi-line message:
   ```
   feat(${story_key}): {task-description}

   Story: ${story_key}
   Task: {task_number}/{total_tasks}
   Epic: ${epic_key}
   ```
3. `git push`

After ALL tasks are implemented and committed, proceed automatically to Step 5.N (code review).

#### 5.N. Adversarial Code Review + Fix Loop (Per Story)

**⚠️ CRITICAL — Workflow Engine Rules:**
Code review and retrospective use YAML-based workflow.yaml files with the workflow engine.
- Load `_bmad/core/tasks/workflow.yaml` FIRST as the execution engine
- Pass the `workflow.yaml` path to the engine
- Follow engine instructions precisely — execute steps sequentially
- Save outputs after completing EACH engine step (never batch)
- STOP and wait for user at decision points

```yaml
# Pre-condition gate: verify story is ready for review
story_check = load("${dev_story_path}")
story_status_check = story_check.status || story_check.Status || "unknown"
if story_status_check not in ["review", "in-progress"]:
  error: |
    ⛔ Code review blocked — story status is "${story_status_check}", not ready for review.
    Complete implementation and signal @lens done before proceeding.
  halt: true

invoke: git-orchestration.start-workflow
params:
  workflow_name: code-review

# RESOLVED: bmm.code-review → Load workflow engine then execute YAML workflow:
#   1. Load engine: _bmad/core/tasks/workflow.yaml
#   2. Pass config: _bmad/bmm/workflows/4-implementation/code-review/workflow.yaml
# Agent persona: Quinn (QA) — load and adopt _bmad/bmm/agents/qa.md
agent_persona: "_bmad/bmm/agents/qa.md"
load_engine: "_bmad/core/tasks/workflow.yaml"
execute_workflow: "_bmad/bmm/workflows/4-implementation/code-review/workflow.yaml"
params:
  target_repo: "${target_path}"
  branch: "${session.story_branch}"
  constitutional_context: ${constitutional_context}
  auto_fix_rerun: true
  auto_fix_severities: "CRITICAL,HIGH,MEDIUM"
  max_review_passes: 2
  on_max_passes: "needs_manual"

# Re-check constitutional compliance on review outputs
refreshed_context = invoke("constitution.resolve-context")
if refreshed_context.status != "parse_error":
  session.constitutional_context = refreshed_context

code_review_path = "_bmad-output/implementation-artifacts/code-review-${id}.md"
code_review_compliance = invoke("constitution.compliance-check")
params:
  artifact_path: ${code_review_path}
  artifact_type: "Code file"
  constitutional_context: ${session.constitutional_context}

if code_review_compliance.article_gate_results:
  review_gates = code_review_compliance.article_gate_results
  if review_gates.failed_gates > 0:
    output: |
      ═══ Post-Review Constitutional Re-Validation ═══
      ${for gate in review_gates.gates where gate.status == "fail"}
      ✗ Article ${gate.article_id}: ${gate.title} (${gate.source_layer})
        ${for item in gate.failed_items}
        → ${item.violation}
        ${endfor}
      ${endfor}
    if enforcement_mode == "enforced":
      invoke: constitution.auto-resolve-gate-block
      params:
        failed_gates: ${review_gates}
        artifact_path: ${code_review_path}
        artifact_type: "Code file"
        initiative_id: ${initiative.id}
        source_branch: current_branch()
        gate_stage: "post-review-revalidation"
      halt: true
    else:
      warning: |
        ⚠️ ${review_gates.failed_gates} article gate warning(s) on code review.

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")

if code_review_compliance.fail_count > 0 and enforcement_mode == "enforced":
  invoke: constitution.auto-resolve-gate-block
  params:
    fail_count: ${code_review_compliance.fail_count}
    artifact_path: ${code_review_path}
    artifact_type: "Code file"
    initiative_id: ${initiative.id}
    source_branch: current_branch()
    gate_stage: "post-review-compliance-legacy"
  halt: true

# RESOLVED: core.party-mode → Read fully and follow:
#   _bmad/core/workflows/party-mode/workflow.md
read_and_follow: "_bmad/core/workflows/party-mode/workflow.md"
params:
  input_file: ${code_review_path}
  artifacts_path: ${target_path}
  output_file: "_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md"
  constitutional_context: ${session.constitutional_context}
  complexity_tracking: ${complexity_tracking}

if party_mode.status not in ["pass", "complete"]:
  error: |
    Party mode teardown found unresolved issues for story ${story_id}.
    Address _bmad-output/implementation-artifacts/party-mode-review-${story_id}.md and fix issues.
  # Fix loop: attempt to resolve and re-review (within max_review_passes)
  halt: true

# ⚠️ MANDATORY — Review Fix Gate: Story must be status "done" before PR creation.
reviewed_story = load(${dev_story_path})
reviewed_story_status = reviewed_story.status || reviewed_story.Status || reviewed_story.story_status || "unknown"

if reviewed_story_status != "done":
  output: |
    ⛔ PR blocked for ${story_id}
    ├── Post-review story status: ${reviewed_story_status}
    ├── Meaning: review follow-ups or unresolved fixes remain
    └── Action: resolve review items and re-review

  invoke: git-orchestration.finish-workflow
  halt: true

# Auto-create story PR in target repo only after review gate passes
invoke: git-orchestration.create-pr
params:
  repo_path: ${target_path}
  source_branch: ${session.story_branch}
  target_branch: ${session.epic_branch}
  title: "feat(${session.epic_key}): ${story_id}"
  body: |
    Story ${story_id} completed and passed the dev → review → fix gate.

    Source branch: ${session.story_branch}
    Target branch: ${session.epic_branch}

    This PR was auto-created by /dev only after review fixes were resolved.
capture: story_pr_result

if story_pr_result.fallback:
  warning: |
    ⚠️ Auto-PR fallback triggered for story ${story_id}.
    Run this in target repo (${target_path}):
    gh pr create --base "${session.epic_branch}" --head "${session.story_branch}" --title "feat(${session.epic_key}): ${story_id}"
else:
  output: |
    ✅ Story PR auto-created
    ├── Branch: ${session.story_branch} → ${session.epic_branch}
    └── URL: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result}

# === NO PER-STORY HARD STOP — Continue to next story immediately ===
# Story PRs are created but NOT waited on. The dev loop continues
# with the next story, which chains off this story's branch.
# Hard stop only occurs at the EPIC level after all stories complete.
output: |
  📋 Story PR created — continuing to next story (no wait).
  ├── Story: ${story_id}
  ├── PR: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result || '(manual — see fallback above)'}
  └── ⚠️  Merge story PRs into epic before epic completion gate.

# Switch back to Amelia (Developer) for next story
invoke: git-orchestration.finish-workflow

# Track story completion
session.stories_completed.append(story_id)

# Commit story completion state to BMAD control repo
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/implementation-artifacts/"
  message: "[lens-work] /dev: Story ${story_id} complete — ${story_idx + 1}/${session.story_files.length}"
  branch: "${initiative.initiative_root}-dev"

output: |
  ✅ Story ${story_id} complete (${story_idx + 1}/${session.story_files.length})
  ├── Stories completed: ${session.stories_completed.length}
  └── Stories remaining: ${session.story_files.length - session.stories_completed.length}

# END STORY LOOP — continue to next story
endfor

output: |
  ═══════════════════════════════════════════
  🎉 All ${session.stories_completed.length} stories in Epic ${session.epic_number} implemented!
  ═══════════════════════════════════════════
  ${for sid in session.stories_completed}
  ✅ ${sid}
  ${endfor}
```

### 5a. Epic Completion Gate (Mandatory)

**⚠️ MANDATORY — Epic Completion Gate: Do NOT skip this section.**
**This step runs after ALL stories in the epic are complete.**
**Both the adversarial review and party-mode teardown are hard gates — failure halts the workflow.**

```yaml
current_epic_id = "epic-${session.epic_number}"

# All stories complete — run epic-level adversarial review
# RESOLVED: bmm.check-implementation-readiness → Read fully and follow:
#   _bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md
read_and_follow: "_bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md"
params:
  scope: "epic"
  epic_id: ${current_epic_id}
  stories: "${docs_path}/stories.md"
  implementation_artifacts: "_bmad-output/implementation-artifacts/"
  constitutional_context: ${constitutional_context}

if epic_adversarial.status in ["blocked", "fail", "failed"]:
  error: |
    ⛔ MANDATORY GATE — Epic adversarial review failed for ${current_epic_id}.
    Resolve implementation-readiness findings and re-run /dev.
  halt: true

# RESOLVED: core.party-mode → Read fully and follow:
#   _bmad/core/workflows/party-mode/workflow.md
read_and_follow: "_bmad/core/workflows/party-mode/workflow.md"
params:
  input_file: "${docs_path}/epics.md"
  focus_epic: ${current_epic_id}
  artifacts_path: ${session.target_path}
  output_file: "_bmad-output/implementation-artifacts/epic-${current_epic_id}-party-mode-review.md"
  constitutional_context: ${constitutional_context}

if party_mode.status not in ["pass", "complete"]:
  error: |
    ⛔ MANDATORY GATE — Epic party-mode teardown found unresolved issues for ${current_epic_id}.
    Address _bmad-output/implementation-artifacts/epic-${current_epic_id}-party-mode-review.md and re-run /dev.
  halt: true

# Push epic branch and create epic-level PR → initiative branch in target repo
invoke: git-orchestration.commit-and-push
params:
  repo_path: ${session.target_path}
  branch: ${session.epic_branch}
  message: "feat(${session.epic_key}): Epic ${session.epic_number} complete — all stories merged"

# Epic PR targets the INITIATIVE branch — NOT develop/main/master directly.
# Epics merge into their initiative branch. The initiative branch is merged
# into the integration branch separately (after all epics in the initiative complete).
target_base_branch = session.initiative_branch

invoke: git-orchestration.create-pr
params:
  repo_path: ${session.target_path}
  source_branch: ${session.epic_branch}
  target_branch: ${target_base_branch}
  title: "feat(${session.epic_key}): Epic ${session.epic_number}"
  body: |
    Epic ${session.epic_number} — all ${session.stories_completed.length} stories implemented and reviewed.

    Stories completed:
    ${for sid in session.stories_completed}
    - ✅ ${sid}
    ${endfor}

    Source branch: ${session.epic_branch}
    Target branch: ${target_base_branch}

    This PR was auto-created by /dev after all stories passed code review and epic-level gates.
    
    ⚠️ All story→epic PRs should be merged before merging this epic→initiative PR.
capture: epic_pr_result

if epic_pr_result.fallback:
  warning: |
    ⚠️ Auto-PR fallback for epic ${session.epic_number}.
    Run this in target repo (${session.target_path}):
    gh pr create --base "${target_base_branch}" --head "${session.epic_branch}" --title "feat(${session.epic_key}): Epic ${session.epic_number}"
else:
  output: |
    ✅ Epic PR auto-created
    ├── Branch: ${session.epic_branch} → ${target_base_branch}
    └── URL: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result}

# === EPIC PR MERGE GATE — HARD STOP ===
# This is the per-epic hard stop. All story PRs should be merged into the epic
# branch before this point. Now wait for the epic→initiative PR to be merged.
output: |
  ⏳ Epic PR Merge Gate — HARD STOP
  ├── PR: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || '(manual — see fallback above)'}
  ├── Branch: ${session.epic_branch} → ${target_base_branch}
  ├── ⚠️  Ensure all story→epic PRs are merged first
  └── ⚠️  Please merge this epic PR now. Waiting up to 10 minutes...

invoke: git-orchestration.wait-for-pr-merge
params:
  repo_path: ${session.target_path}
  source_branch: ${session.epic_branch}
  target_branch: ${target_base_branch}
  pr_url: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || "(manual)"}
  timeout_seconds: 600
capture: epic_merge_wait_result

if epic_merge_wait_result.merged == false:
  output: |
    ❌ Epic PR not merged within 10 minutes — STOPPING.
    ├── Epic: ${session.epic_key}
    ├── PR: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || '(manual)'}
    ├── Action: Merge all story PRs into epic, then merge epic PR into initiative.
    └── Re-run /dev to continue with post-epic steps.
  invoke: git-orchestration.finish-workflow
  halt: true

output: |
  ✅ Epic PR merged into initiative branch.
  └── ${session.epic_key} integrated into ${target_base_branch}

# After epic PR: switch back to Amelia (Developer) — _bmad/bmm/agents/dev.md
invoke: git-orchestration.finish-workflow
```

### 6. Retrospective (optional)

```yaml
offer: "Run retrospective? [Y]es / [N]o"

if yes:
  invoke: git-orchestration.start-workflow
  params:
    workflow_name: retro

  # RESOLVED: bmm.retrospective → Load workflow engine then execute YAML workflow:
  #   1. Load engine: _bmad/core/tasks/workflow.yaml
  #   2. Pass config: _bmad/bmm/workflows/4-implementation/retrospective/workflow.yaml
  # Agent persona: Switch to Bob (Scrum Master) — load and adopt _bmad/bmm/agents/sm.md
  agent_persona: "_bmad/bmm/agents/sm.md"
  load_engine: "_bmad/core/tasks/workflow.yaml"
  execute_workflow: "_bmad/bmm/workflows/4-implementation/retrospective/workflow.yaml"
  params:
    constitutional_context: ${constitutional_context}
  invoke: git-orchestration.finish-workflow
```

### 7. Update State Files & Initiative Config

```yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "dev"
    phase_status:
      dev: "in_progress"
    gates:
      large_to_base:
        status: "passed"
        verified_at: "${ISO_TIMESTAMP}"
      dev_started:
        status: "in_progress"
        started_at: "${ISO_TIMESTAMP}"
        story_id: "${story_id}"

invoke: state-management.update-state
params:
  updates:
    current_phase: "dev"
    active_branch: "${initiative.initiative_root}-dev"
    workflow_status: "in_progress"
```

### 8. Commit State Changes

```yaml
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/lens-work/event-log.jsonl"
    - "_bmad-output/implementation-artifacts/"
  message: "[lens-work] /dev: Dev Implementation — ${initiative.id} — ${story_id}"
  branch: "${initiative.initiative_root}-dev"
```

### 9. Log Event

```json
{"ts":"${ISO_TIMESTAMP}","event":"dev","id":"${initiative.id}","phase":"dev","workflow":"dev","story":"${story_id}","status":"in_progress"}
```

### 10. Complete Initiative (when all done)

```yaml
if all_phases_complete():
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      status: "complete"
      completed_at: "${ISO_TIMESTAMP}"
      phase_status:
        dev: "complete"

  invoke: state-management.archive
  
  invoke: git-orchestration.commit-and-push
  params:
    paths:
      - "_bmad-output/lens-work/"
    message: "[lens-work] Initiative complete — ${initiative.id}"
  
  output: |
    🎉 Initiative Complete!
    ├── All phases finished
    ├── Code merged to main
    ├── Initiative archived
    └── Great work, team!
```

---

## Control-Plane Rule Reminder

Throughout `/dev`, the user may work in TargetProjects for actual coding, but all lens-work commands continue to execute from the BMAD directory:

| Action | Location | Note |
|--------|----------|------|
| Write code / create files | TargetProjects/${repo} (session.target_path) | **ONLY here** |
| Run /dev commands | BMAD directory | Control plane |
| Read framework files | bmad.lens.release/ | **READ-ONLY — never write here** |
| State tracking writes | _bmad-output/ | Sprint status, initiative config |

**⚠️ bmad.lens.release is NEVER the implementation target.** It is a read-only authority repo containing BMAD framework code.
| Code review | BMAD directory |
| Status checks | BMAD directory |

---

## Output Artifacts

| Artifact | Location |
|----------|----------|
| Code Review Report | `_bmad-output/implementation-artifacts/code-review-${id}.md` |
| Party Mode Review Report | `_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md` |
| Epic Party Mode Review Report | `_bmad-output/implementation-artifacts/epic-*-party-mode-review.md` |
| Complexity Tracking | `{bmad_docs}/complexity-tracking.md` |
| Retro Notes | `_bmad-output/implementation-artifacts/retro-${id}.md` |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` |
| Event Log | `_bmad-output/lens-work/event-log.jsonl` |

---

## Error Handling

| Error | Recovery |
|-------|----------|
| No dev story | Prompt to run /sprintplan first |
| SprintPlan not merged | Error with merge gate blocked message |
| Constitution gate not passed | Auto-triggers audience promotion (large → base) |
| Audience promotion failed | Error — must complete large → base promotion |
| Dirty working directory | Prompt to stash or commit changes first |
| Target repo checkout failed | Check target_repos config, retry |
| Branch creation failed | Check remote connectivity, retry with backoff |
| Dev story compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Article-specific gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Pre-implementation gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Checklist quality gate failed | Complete checklist items or override with justification |
| Code review failed | Allow retry or manual review |
| Code review compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Post-review re-validation failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Party mode teardown failed | Address party-mode findings and re-run code review |
| Epic adversarial review failed | Resolve implementation-readiness findings for the epic and re-run code review |
| Epic party mode teardown failed | Address epic party-mode findings and re-run code review |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |

---

## Post-Conditions

- [ ] Working directory clean (all changes committed)
- [ ] On correct branch: `{initiative_root}-dev`
- [ ] Audience promotion validated (large → base passed)
- [ ] initiatives/{id}.yaml updated with dev status and gate entries
- [ ] event-log.jsonl entries appended
- [ ] All stories for the epic discovered and implemented
- [ ] Each story: constitution check passed, pre-implementation gates passed
- [ ] Each task: individually committed to story branch
- [ ] Each story: adversarial code review executed with fix loop (max 2 passes)
- [ ] Each story: party mode teardown passed
- [ ] Each story: PR created (story branch → epic branch)
- [ ] Epic completion gate: adversarial review and party-mode teardown passed
- [ ] Constitutional guidance surfaced with special instructions (if provided)
- [ ] Target repo feature branches used for implementation
- [ ] Epic adversarial review executed when epic completion is detected
- [ ] Epic party-mode teardown executed when epic completion is detected
- [ ] All state changes pushed to origin
