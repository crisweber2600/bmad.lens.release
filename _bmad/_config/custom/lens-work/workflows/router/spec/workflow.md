---
name: businessplan
description: Launch BusinessPlan phase (PRD/UX Design)
agent: "@lens"
trigger: /businessplan command
aliases: [/spec]
category: router
phase_name: businessplan
display_name: BusinessPlan
agent_owner: john
agent_role: PM
supporting_agents: [sally]
imports: lifecycle.yaml
---

# /businessplan — BusinessPlan Phase Router

**Purpose:** Guide users through the BusinessPlan phase, invoking PRD and UX design workflows.

**Lifecycle:** `businessplan` phase, audience `small`, owned by John (PM) with Sally (UX Designer) support.

---

## Role Authorization

**Authorized:** PO, Architect, Tech Lead

---

## Prerequisites

- [x] `/preplan` complete (preplan phase merged into small audience branch)
- [x] Product Brief exists
- [x] state.yaml + initiatives/{id}.yaml exist
- [x] preplan gate passed (PrePlan artifacts committed)

---

## Execution Sequence

### 0. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 1. Verify working directory is clean
# 2. Load two-file state (state.yaml + initiative config)
# 3. Check previous phase status (preplan must be complete)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to artifact work

# Verify working directory is clean
invoke: git-orchestration.verify-clean-state

# Load two-file state
state = load("_bmad-output/lens-work/state.yaml")
initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}.yaml")

# Load lifecycle contract for phase → audience mapping
lifecycle = load("lifecycle.yaml")

# Read initiative config
size = initiative.size
domain_prefix = initiative.domain_prefix

# Derive audience from lifecycle contract (businessplan → small)
current_phase = "businessplan"
audience = lifecycle.phases[current_phase].audience    # "small"
initiative_root = initiative.initiative_root
audience_branch = "${initiative_root}-${audience}"     # {initiative_root}-small

# === Path Resolver (S01-S06: Context Enhancement) ===
docs_path = initiative.docs.path    # e.g., "docs/BMAD/LENS/BMAD.Lens/context-enhancement-9bfe4e"
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  # Fallback for older initiatives without docs block
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."
  warning: "  → Run: /lens migrate <initiative-id> to add docs.path"
  warning: "  → This fallback will be removed in a future version."

output_path = docs_path
ensure_directory(output_path)

# === Context Loader (S08: Context Enhancement) ===
product_brief = load_file("${docs_path}/product-brief.md")
if product_brief == null:
  FAIL("Product brief not found at ${docs_path}/product-brief.md")

if repo_docs_path != null:
  repo_readme = load_if_exists("${repo_docs_path}/README.md")
  repo_architecture = load_if_exists("${repo_docs_path}/ARCHITECTURE.md")
  repo_context = { readme: repo_readme, architecture: repo_architecture }
else:
  repo_context = null

# REQ-7/REQ-9: Validate previous phase PR merged [S1.5]
# Previous phase: preplan (same audience — small)
prev_phase = "preplan"
prev_phase_branch = "${initiative_root}-${audience}-preplan"

if initiative.phase_status[prev_phase] exists:
  if initiative.phase_status[prev_phase].status == "pr_pending":
    # Check if the audience branch contains the phase commits (merged via PR)
    result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_phase_branch} origin/${audience_branch}")

    if result.exit_code == 0:
      # PR was merged! Auto-update status
      invoke: state-management.update-initiative
      params:
        initiative_id: ${initiative.id}
        updates:
          phase_status:
            preplan:
              status: "complete"
              completed_at: "${ISO_TIMESTAMP}"
      output: "✅ Previous phase (preplan) PR merged — status updated to complete"
    else:
      # PR not merged yet — warn but allow proceeding
      pr_url = initiative.phase_status[prev_phase].pr_url || "(no PR URL recorded)"
      output: |
        ⚠️  Previous phase (preplan) PR not yet merged
        ├── Status: pr_pending
        ├── PR: ${pr_url}
        └── You may continue, but phase artifacts may not be on the audience branch

      ask: "Continue anyway? [Y]es / [N]o"
      if no:
        exit: 0  # User chose to wait for merge

# Determine phase branch [REQ-9]
phase_branch = "${initiative_root}-${audience}-businessplan"

# Step 5: Create phase branch if it doesn't exist [REQ-9]
if not branch_exists(phase_branch):
  invoke: git-orchestration.start-phase
  params:
    phase_name: "businessplan"
    display_name: "BusinessPlan"
    initiative_id: ${initiative.id}
    audience: ${audience}
    initiative_root: ${initiative_root}
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
  ├── Phase: BusinessPlan (businessplan)
  ├── Audience: small
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 1. Validate Prerequisites & Gate Check

```yaml
# Gate check — verify preplan phase artifacts exist
# Branch pattern: {initiative_root}-{audience}-{phase_name}
preplan_branch = "${initiative_root}-${audience}-preplan"

if not phase_complete("preplan"):
  # Ancestry check: preplan must be merged into audience branch
  result = git-orchestration.exec("git merge-base --is-ancestor origin/${preplan_branch} origin/${audience_branch}")

  if result.exit_code != 0:
    error: "PrePlan phase not complete. Run /preplan first or merge pending PRs."

# Verify preplan artifacts exist
required_artifacts:
  - "${docs_path}/product-brief.md"

for artifact in required_artifacts:
  if not file_exists(artifact):
    # Fallback: check legacy path for backward compatibility
    legacy_path = artifact.replace("${docs_path}/", "_bmad-output/planning-artifacts/")
    if file_exists(legacy_path):
      warning: "Found artifact at legacy path: ${legacy_path}. Consider migrating."
    else:
      warning: "Required artifact not found: ${artifact}. Proceeding but businessplan quality may suffer."
```

### 1a. Constitution Compliance Gate (ADVISORY)

```yaml
# Invoke compliance-check to verify inherited constitution constraints
# Mode: ADVISORY (log warnings, do not block)
invoke: lens-work.compliance-check
params:
  phase: "businessplan"
  phase_name: "BusinessPlan"
  initiative_id: ${initiative.id}
  target_repos: ${initiative.target_repos}
  mode: "ADVISORY"

# Compliance check logs findings to _bmad-output/lens-work/compliance-reports/
# Warnings are surfaced to user but do not block workflow progression
```

### 2. Branch Verification (consolidated into Pre-Flight)

```yaml
# Branch creation and checkout handled in Step 0 Pre-Flight [REQ-9]
# Phase branch ${phase_branch} is already checked out at this point.
assert: current_branch == phase_branch
```

### 2a. Constitutional Context Injection (Required)

```yaml
# Resolve constitutional governance for this context before planning workflows
constitutional_context = invoke("constitution.resolve-context")

if constitutional_context.status == "parse_error":
  error: |
    Constitutional context parse error:
    ${constitutional_context.error_details.file}
    ${constitutional_context.error_details.error}

session.constitutional_context = constitutional_context
```

### 2b. Batch Mode (Single-File Questions)

```yaml
if initiative.question_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "businessplan"
    display_name: "BusinessPlan"
    template_path: "templates/businessplan-questions.template.md"
    output_filename: "businessplan-questions.md"
  exit: 0
```

### 3. Offer Workflow Options

```
🧭 /businessplan — BusinessPlan Phase

You're starting the Planning phase. Workflows:

**[1] PRD** (required) — Product Requirements Document
**[2] UX Design** (if UI involved) — User experience design

Select workflow(s): [1] [2] [A]ll
```

### 4. Execute Workflows

#### PRD:
```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: prd

invoke: bmm.create-prd
params:
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow
```

#### UX (if selected):
```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: ux-design

invoke: bmm.create-ux-design
params:
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow
```

### 5. Phase Completion — Push Only

```yaml
# REQ-7: Never auto-merge. PR created in S1.2.
if all_workflows_complete("businessplan"):
  invoke: git-orchestration.commit-and-push
  params:
    branch: ${phase_branch}
    message: "[${initiative.id}] BusinessPlan complete"
  # Phase branch remains alive — PR handles merge to audience branch

  # REQ-8: Create PR for phase merge
  invoke: git-orchestration.create-pr
  params:
    head: ${phase_branch}
    base: ${audience_branch}
    title: "[businessplan] BusinessPlan: ${initiative.name}"
    body: "BusinessPlan phase complete for ${initiative.id}.\n\nArtifacts: prd.md, ux-design.md"
  capture: pr_result  # { url, number } or fallback message

  # REQ-7/REQ-8: Phase enters pr_pending after PR creation
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      phase_status:
        businessplan:
          status: "pr_pending"
          pr_url: "${pr_result.url}"
          pr_number: ${pr_result.number}
  # If manual fallback (no PAT), still set pr_pending with null PR info
  if pr_result.fallback:
    invoke: state-management.update-initiative
    params:
      initiative_id: ${initiative.id}
      updates:
        phase_status:
          businessplan:
            status: "pr_pending"
            pr_url: null
            pr_number: null

  output: |
    ✅ /businessplan complete
    ├── Phase: BusinessPlan (businessplan) finished
    ├── Audience: small
    ├── Branch pushed: ${phase_branch}
    ├── PR: ${pr_result}
    ├── Status: pr_pending (awaiting merge)
    ├── Remaining on: ${phase_branch}
    └── Next: Run /techplan to continue to TechPlan phase
```

### 6. Update State Files

```yaml
# Update initiative file: _bmad-output/lens-work/initiatives/${initiative.id}.yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "businessplan"
    phase_status:
      businessplan:
        status: "in_progress"
        started_at: "${ISO_TIMESTAMP}"
      preplan:
        status: "complete"

# Update state.yaml
invoke: state-management.update-state
params:
  updates:
    current_phase: "businessplan"
    workflow_status: "pr_pending"
    active_branch: "${phase_branch}"
```

### 7. Commit State Changes

```yaml
# git-orchestration commits all state and artifact changes
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/state.yaml"
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/lens-work/event-log.jsonl"
    - "${docs_path}/"
  message: "[lens-work] /businessplan: BusinessPlan — ${initiative.id}"
  branch: "${phase_branch}"
```

### 8. Log Event

```json
{"ts":"${ISO_TIMESTAMP}","event":"businessplan","id":"${initiative.id}","phase":"businessplan","audience":"small","workflow":"businessplan","status":"complete"}
```

---

## Output Artifacts

| Artifact | Location |
|----------|----------|
| PRD | `${docs_path}/prd.md` |
| UX Design | `${docs_path}/ux-design.md` |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` |

---

## Error Handling

| Error | Recovery |
|-------|----------|
| PrePlan not complete | Error with merge instructions |
| Product brief missing | Warn but allow proceeding |
| Dirty working directory | Prompt to stash or commit changes first |
| Branch creation failed | Check remote connectivity, retry with backoff |
| PrePlan ancestry check failed | Prompt to merge preplan PR before continuing |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |

---

## Post-Conditions

- [ ] Working directory clean (all changes committed)
- [ ] On phase branch: `{initiative_root}-small-businessplan` (REQ-7: no auto-merge)
- [ ] state.yaml updated with phase businessplan
- [ ] initiatives/{id}.yaml phase_status.businessplan updated, preplan marked complete
- [ ] event-log.jsonl entry appended
- [ ] Planning artifacts written to `${docs_path}/` (PRD; optionally UX)
- [ ] All changes pushed to origin
