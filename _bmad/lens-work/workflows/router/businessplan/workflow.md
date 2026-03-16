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
- [x] preplan gate passed (PrePlan artifacts committed)

---

## Execution Sequence

### 0. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 1. Verify working directory is clean
# 2. Derive initiative state from git branch (v2: git-state skill)
# 3. Check previous phase status (preplan must be complete)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to artifact work

# Verify working directory is clean
invoke: git-orchestration.verify-clean-state

# Derive initiative state from git branch (v2: git-state skill)
initiative_state = invoke: git-state.current-initiative
initiative = load("${initiative_state.config_path}")

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
docs_path = initiative.docs.path
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."
  warning: "  → Run: /lens migrate <initiative-id> to add docs.path"

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
prev_phase = "preplan"
prev_phase_branch = "${initiative_root}-${audience}-preplan"

if initiative.phase_status[prev_phase] exists:
  if initiative.phase_status[prev_phase].status == "pr_pending":
    result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_phase_branch} origin/${audience_branch}")

    if result.exit_code == 0:
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
      pr_url = initiative.phase_status[prev_phase].pr_url || "(no PR URL recorded)"
      output: |
        ⚠️  Previous phase (preplan) PR not yet merged
        ├── Status: pr_pending
        ├── PR: ${pr_url}
        └── You may continue, but phase artifacts may not be on the audience branch

      ask: "Continue anyway? [Y]es / [N]o"
      if no:
        exit: 0

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
preplan_branch = "${initiative_root}-${audience}-preplan"

if not phase_complete("preplan"):
  result = git-orchestration.exec("git merge-base --is-ancestor origin/${preplan_branch} origin/${audience_branch}")

  if result.exit_code != 0:
    error: "PrePlan phase not complete. Run /preplan first or merge pending PRs."

# Verify preplan artifacts exist
required_artifacts:
  - "${docs_path}/product-brief.md"

for artifact in required_artifacts:
  if not file_exists(artifact):
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
```

### 2. Branch Verification (consolidated into Pre-Flight)

```yaml
# Branch creation and checkout handled in Step 0 Pre-Flight [REQ-9]
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

### 2b. Execution Mode Selection (Interactive or Batch)

```yaml
ask: |
  📋 Execution Mode Selection
  
  How would you like to proceed with this phase?
  
  **[I] Interactive** — Choose workflows and answer step-by-step
  **[B] Batch**     — Answer all questions at once in a single file
  
  Select mode: [I] or [B]
  (Default: ${initiative.question_mode})

raw_choice = user_input
normalized_choice = null

if raw_choice:
  upper_choice = raw_choice.upper()
  if upper_choice == "B" or upper_choice == "BATCH":
    normalized_choice = "batch"
  elif upper_choice == "I" or upper_choice == "INTERACTIVE":
    normalized_choice = "interactive"

session.execution_mode = normalized_choice || initiative.question_mode
session.mode_switched = (session.execution_mode != initiative.question_mode) ? true : false
session.mode_switch_point = "entry"

log_event:
  type: "execution_mode_selected"
  phase: "businessplan"
  mode: "${session.execution_mode}"
  global_default: "${initiative.question_mode}"
  override: ${session.mode_switched}
  timestamp: "${ISO_TIMESTAMP}"

if session.execution_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "businessplan"
    display_name: "BusinessPlan"
    template_path: "templates/businessplan-questions.template.md"
    output_filename: "businessplan-questions.md"
    scope: "phase"
  output: |
    ✅ Batch responses processed for BusinessPlan
    ├── Questionnaire updated: ${docs_path}/businessplan-questions.md
    └── Continuing to phase completion (commit, push, and PR creation)
```

### 3. Offer Workflow Options (Interactive Mode Only)

Skip this section when `session.execution_mode == "batch"`.

```
🧭 /businessplan — BusinessPlan Phase

You're starting the Planning phase. Workflows:

**[1] PRD** (required) — Product Requirements Document
**[2] UX Design** (if UI involved) — User experience design
**[3] Architecture** (required) — Technical architecture design

Select workflow(s): [1] [2] [3] [A]ll
```

### 4. Execute Workflows (Interactive Mode Only)

Skip this section when `session.execution_mode == "batch"`.

**⚠️ CRITICAL — Interactive Workflow Rules:**
Each sub-workflow uses sequential step-file architecture.
- 🛑 **NEVER** auto-complete or batch-generate content without user input
- ⏸️ **ALWAYS** STOP and wait for user input/confirmation at each step
- 🚫 **NEVER** load the next step file until user explicitly confirms (Continue / C)
- 📋 Back-and-forth dialogue is REQUIRED — you are a facilitator, not a generator
- 💾 Save/update frontmatter after completing each step before loading the next
- 🎯 Read the ENTIRE step file before taking any action within it

#### PRD:
```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: prd

# RESOLVED: bmm.create-prd → Read fully and follow this workflow file:
#   _bmad/bmm/workflows/2-plan-workflows/create-prd/workflow-create-prd.md
# Agent persona: John (PM) — load and adopt _bmad/bmm/agents/pm.md
# Uses step-file architecture with steps-c/ folder
# Load steps one at a time (JIT) — NEVER load multiple step files simultaneously
# ALWAYS halt at menus and wait for user input before proceeding
agent_persona: "_bmad/bmm/agents/pm.md"
read_and_follow: "_bmad/bmm/workflows/2-plan-workflows/create-prd/workflow-create-prd.md"
params:
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

# After PRD creation, run PRD validation:
# RESOLVED: Read fully and follow:
#   _bmad/bmm/workflows/2-plan-workflows/create-prd/workflow-validate-prd.md
# Continue as John (PM) — adversarial review of PRD for completeness and buildability
read_and_follow: "_bmad/bmm/workflows/2-plan-workflows/create-prd/workflow-validate-prd.md"
params:
  prd_path: "${docs_path}/prd.md"

invoke: git-orchestration.finish-workflow
```

#### UX (if selected):
```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: ux-design

# RESOLVED: bmm.create-ux-design → Read fully and follow this workflow file:
#   _bmad/bmm/workflows/2-plan-workflows/create-ux-design/workflow.md
# Agent persona: Switch to Sally (UX Designer) — load and adopt _bmad/bmm/agents/ux-designer.md
# Uses step-file architecture with steps/ folder
# Load steps one at a time (JIT) — NEVER load multiple step files simultaneously
# ALWAYS halt at menus and wait for user input before proceeding
agent_persona: "_bmad/bmm/agents/ux-designer.md"
read_and_follow: "_bmad/bmm/workflows/2-plan-workflows/create-ux-design/workflow.md"
params:
  prd: "${docs_path}/prd.md"
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow
```

#### Architecture — Technical Spec Generation:
```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: architecture

# RESOLVED: bmm.create-architecture → Read fully and follow this workflow file:
#   _bmad/bmm/workflows/3-solutioning/create-architecture/workflow.md
# Agent persona: Switch to Winston (Architect) — load and adopt _bmad/bmm/agents/architect.md
# Uses step-file architecture with steps/ folder
# Load steps one at a time (JIT) — NEVER load multiple step files simultaneously
# ALWAYS halt at menus and wait for user input before proceeding
agent_persona: "_bmad/bmm/agents/architect.md"
read_and_follow: "_bmad/bmm/workflows/3-solutioning/create-architecture/workflow.md"
params:
  prd: "${docs_path}/prd.md"
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow
```

### 5. Phase Completion — Commit, Push, and PR

> **⛔ MANDATORY EPILOGUE — NEVER SKIP**
> Steps 5–8 below MUST execute after artifact generation completes,
> regardless of how artifacts were produced (interactive, batch, YOLO, or
> recovery from interruption). Committing artifacts without creating the
> PR leaves the phase in a broken state. If you have committed and pushed
> artifacts, you are NOT done — continue executing from this point.

```yaml
# REQ-7: Never auto-merge. PR created in S1.2.
# Batch mode must continue here after questionnaire processing (no early exit).
has_prd = file_exists("${docs_path}/prd.md")
has_ux_design = file_exists("${docs_path}/ux-design.md")
has_ux_design_spec = file_exists("${docs_path}/ux-design-specification.md")
businessplan_ready = has_prd && (has_ux_design || has_ux_design_spec)

if businessplan_ready:
  ux_artifact_name = has_ux_design ? "ux-design.md" : "ux-design-specification.md"

  invoke: git-orchestration.commit-and-push
  params:
    branch: ${phase_branch}
    message: "[${initiative.id}] BusinessPlan complete"

  # REQ-8: Create PR for phase merge using create-pr script (PAT + API, no gh CLI)
  invoke: script
  script: "${PROJECT_ROOT}/_bmad/lens-work/scripts/create-pr.ps1"  # or .sh on Unix
  params:
    SourceBranch: ${phase_branch}
    TargetBranch: ${audience_branch}
    Title: "[PHASE] ${initiative.id} — BusinessPlan complete"
    Body: "BusinessPlan phase complete for ${initiative.id}.\n\nPhase: businessplan\nAudience: small\nArtifacts: prd.md, ux-design.md\n\n---\n*Generated by lens-work/workflows/router/businessplan*"
  capture: pr_result

  # REQ-7/REQ-8: Phase enters pr_pending after PR creation
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      phase_status:
        businessplan:
          status: "pr_pending"
          pr_url: "${pr_result.pr_url || pr_result.url || pr_result}"
          pr_number: ${pr_result.pr_number || pr_result.number || null}
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
else:
  missing = []
  if not has_prd:
    missing.push("prd.md")
  if not (has_ux_design || has_ux_design_spec):
    missing.push("ux-design.md (or ux-design-specification.md)")
  FAIL("❌ BusinessPlan phase incomplete. Missing required artifacts: ${missing.join(', ')}")
```

### 6. Update State Files

```yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "businessplan"
    phase_status:
      businessplan:
        status: "pr_pending"
      preplan:
        status: "complete"

invoke: state-management.update-state
params:
  updates:
    current_phase: "businessplan"
    workflow_status: "pr_pending"
    active_branch: "${phase_branch}"
```

### 7. Commit State Changes

```yaml
invoke: git-orchestration.commit-and-push
params:
  paths:
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

### Step 9: Offer Next Step

```
Ready to continue?

**[C]** Continue to /techplan (TechPlan phase)
**[P]** Pause here (resume later with @lens /techplan)
**[S]** Show status (@lens ST)
```

### Step 10: Check Promotion Readiness

Execute the promotion-check include from `_bmad/lens-work/workflows/includes/promotion-check.md`:

```yaml
invoke: include
path: "_bmad/lens-work/workflows/includes/promotion-check.md"
params:
  current_phase: "businessplan"
  initiative_root: "${initiative.id}"
  current_audience: "small"
  lifecycle_contract: load("lifecycle.yaml")
```

**Purpose:** Check if promotion to the next audience is available after businessplan completion. If all phases for the current audience are complete, offer the promote workflow. Otherwise, display pending phases.

---

## Output Artifacts

| Artifact | Location |
|----------|----------|
| PRD | `${docs_path}/prd.md` |
| UX Design | `${docs_path}/ux-design.md` or `${docs_path}/ux-design-specification.md` |
| Architecture | `${docs_path}/architecture.md` |
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
| Architecture workflow failed | Retry or skip with warning |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |

---

## Post-Conditions

- [ ] Working directory clean (all changes committed)
- [ ] On phase branch: `{initiative_root}-small-businessplan` (REQ-7: no auto-merge)
- [ ] initiatives/{id}.yaml phase_status.businessplan updated, preplan marked complete
- [ ] event-log.jsonl entry appended
- [ ] Planning artifacts written to `${docs_path}/` (PRD; optionally UX)
- [ ] All changes pushed to origin
