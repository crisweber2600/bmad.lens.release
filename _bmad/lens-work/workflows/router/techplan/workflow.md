---
name: techplan
description: Architecture and technical design phase
agent: "@lens"
trigger: /techplan command
aliases: [/tech-plan]
category: router
phase_name: techplan
display_name: TechPlan
agent_owner: winston
agent_role: Architect
imports: lifecycle.yaml
---

# /techplan — TechPlan Phase Router

**Purpose:** Guide users through the TechPlan phase — architecture, technical design, API contracts, and technology decisions.

**Lifecycle:** `techplan` phase, audience `small`, owned by Winston (Architect).

---

## Role Authorization

**Authorized:** Architect, Tech Lead (phase owner: Winston/Architect)

---

## Prerequisites

- [x] `/businessplan` complete (businessplan phase merged into small audience branch)
- [x] PRD exists
- [x] businessplan gate passed (BusinessPlan artifacts committed)

---

## Gate Chain Position

```
(none) → preplan → businessplan → [techplan] → devproposal → sprintplan → dev
```

---

## Execution Sequence

### 0. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 1. Verify working directory is clean
# 2. Derive initiative state from git branch (v2: git-state skill)
# 3. Check previous phase status (businessplan must be complete)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to artifact work
# NOTE: techplan is in the SAME audience (small) as businessplan — no cascade merge needed

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
docs_path = initiative.docs.path
output_path = docs_path
ensure_directory(output_path)

# Derive audience from lifecycle contract (techplan → small)
current_phase = "techplan"
audience = lifecycle.phases[current_phase].audience    # "small"
initiative_root = initiative.initiative_root
audience_branch = "${initiative_root}-${audience}"     # {initiative_root}-small

# REQ-7/REQ-9: Validate previous phase PR merged [S1.5]
# Previous phase: businessplan (same audience — small)
prev_phase = "businessplan"
prev_phase_branch = "${initiative_root}-${audience}-businessplan"

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
            businessplan:
              status: "complete"
              completed_at: "${ISO_TIMESTAMP}"
      output: "✅ Previous phase (businessplan) PR merged — status updated to complete"
    else:
      # PR not merged yet — warn but allow proceeding
      pr_url = initiative.phase_status[prev_phase].pr_url || "(no PR URL recorded)"
      output: |
        ⚠️  Previous phase (businessplan) PR not yet merged
        ├── Status: pr_pending
        ├── PR: ${pr_url}
        └── You may continue, but phase artifacts may not be on the audience branch

      ask: "Continue anyway? [Y]es / [N]o"
      if no:
        exit: 0  # User chose to wait for merge

# Determine phase branch [REQ-9]
# techplan is in small audience — NO cascade merge needed (same audience as businessplan)
phase_branch = "${initiative_root}-${audience}-techplan"

# Step 5: Create phase branch if it doesn't exist [REQ-9]
if not branch_exists(phase_branch):
  invoke: git-orchestration.start-phase
  params:
    phase_name: "techplan"
    display_name: "TechPlan"
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
  ├── Phase: TechPlan (techplan)
  ├── Audience: small
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 1. Validate Prerequisites & Gate Check

```yaml
# Gate check — verify businessplan phase artifacts exist
if not gate_passed("businessplan"):
  error: "BusinessPlan phase not complete. Run /businessplan first or merge pending PRs."
  exit: 1

# Verify businessplan artifacts exist
required_artifacts:
  - "${docs_path}/prd.md"

for artifact in required_artifacts:
  if not file_exists(artifact):
    warning: "Required artifact not found: ${artifact}. Proceeding but techplan quality may suffer."
```

### 2. Branch Verification (consolidated into Pre-Flight)

```yaml
# Branch creation handled in Step 0 Pre-Flight [REQ-9]
# Phase branch ${phase_branch} is already checked out at this point.
assert: current_branch == phase_branch
```

### 3. Execution Mode Selection (Interactive or Batch)

```yaml
# Allow per-phase override of global question_mode preference
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
  phase: "techplan"
  mode: "${session.execution_mode}"
  global_default: "${initiative.question_mode}"
  override: ${session.mode_switched}
  timestamp: "${ISO_TIMESTAMP}"

if session.execution_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "techplan"
    display_name: "TechPlan"
    template_path: "templates/techplan-questions.template.md"
    output_filename: "techplan-questions.md"
    scope: "phase"
  exit: 0
```

### 4. Architecture Design

**⚠️ CRITICAL — Interactive Workflow Rules:**
Each sub-workflow uses sequential step-file architecture.
- 🛑 **NEVER** auto-complete or batch-generate content without user input
- ⏸️ **ALWAYS** STOP and wait for user input/confirmation at each step
- 🚫 **NEVER** load the next step file until user explicitly confirms (Continue / C)
- 📋 Back-and-forth dialogue is REQUIRED — you are a facilitator, not a generator
- 💾 Save/update frontmatter after completing each step before loading the next
- 🎯 Read the ENTIRE step file before taking any action within it

**Agent:** Adopt Winston (Architect) persona — load `_bmad/bmm/agents/architect.md`

```yaml
# Load context from previous phases
product_brief = load_file("${docs_path}/product-brief.md")
prd = load_file("${docs_path}/prd.md")
epics = load_if_exists("${docs_path}/epics.md")

output: |
  🏗️ TechPlan Phase

  We'll now design the technical architecture based on:
  - Product Brief (from preplan)
  - PRD (from businessplan)
  
  This phase produces:
  1. Architecture document
  2. Technology decisions log
  3. API contracts (if applicable)
  4. Data model specification (if applicable)

# RESOLVED: workflow-step architecture-design → Read fully and follow:
#   _bmad/bmm/workflows/3-solutioning/create-architecture/workflow.md
# Agent persona: Winston (Architect) — _bmad/bmm/agents/architect.md
# Context: pass existing architecture.md as baseline for refinement
# Uses step-file architecture with steps/ folder — load steps one at a time
# NEVER load multiple step files simultaneously
# ALWAYS halt at menus and wait for user input before proceeding
agent_persona: "_bmad/bmm/agents/architect.md"
read_and_follow: "_bmad/bmm/workflows/3-solutioning/create-architecture/workflow.md"
params:
  context: { product_brief, prd, epics }
  output_file: "${docs_path}/architecture.md"

# Tech decisions — inline workflow (continue as Winston)
invoke: workflow-step
params:
  step: tech-decisions
  context: { product_brief, prd }
  output_file: "${docs_path}/tech-decisions.md"

# Optional: API contracts
ask: "Does this initiative involve API contracts? [Y/n]"
if answer == "Y":
  invoke: workflow-step
  params:
    step: api-contracts
    context: { architecture }
    output_file: "${docs_path}/api-contracts.md"

# RESOLVED: Implementation readiness check → Read fully and follow:
#   _bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md
# Validate architecture is buildable and stories can be derived from it
read_and_follow: "_bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md"
params:
  architecture: "${docs_path}/architecture.md"
  prd: "${docs_path}/prd.md"
  tech_decisions: "${docs_path}/tech-decisions.md"
```

### 5. Commit Artifacts

```yaml
# REQ-7: Never auto-merge. PR created in S1.2.
invoke: git-orchestration.targeted-commit
params:
  branch: ${phase_branch}
  files:
    - "${docs_path}/architecture.md"
    - "${docs_path}/tech-decisions.md"
    - "${docs_path}/api-contracts.md"  # if created
  message: "[lens-work] techplan: architecture and technical design"
```

### 6. Phase Completion

> **⛔ MANDATORY EPILOGUE — NEVER SKIP**
> Steps 6–10 below MUST execute after artifact generation completes,
> regardless of how artifacts were produced (interactive, batch, YOLO, or
> recovery from interruption). Committing artifacts without creating the
> PR leaves the phase in a broken state. If you have committed and pushed
> artifacts, you are NOT done — continue executing from this point.

```yaml
if all_workflows_complete("techplan"):
  # Push final state to phase branch
  invoke: git-orchestration.commit-and-push
  params:
    branch: ${phase_branch}
    message: "[${initiative.id}] TechPlan complete"

  # REQ-8: Create PR for phase merge using create-pr script (PAT + API, no gh CLI)
  invoke: script
  script: "${PROJECT_ROOT}/_bmad/lens-work/scripts/create-pr.ps1"  # or .sh on Unix
  params:
    SourceBranch: ${phase_branch}
    TargetBranch: ${audience_branch}
    Title: "[PHASE] ${initiative.id} — TechPlan complete"
    Body: "TechPlan phase complete for ${initiative.id}.\n\nPhase: techplan\nAudience: small\nArtifacts: architecture.md\n\n---\n*Generated by lens-work/workflows/router/techplan. Ready for promotion to medium audience.*"
  capture: pr_result

  # REQ-7/REQ-8: Phase enters pr_pending after PR creation
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      phase_status:
        techplan:
          status: "pr_pending"
          pr_url: "${pr_result.pr_url || pr_result.url || pr_result}"
          pr_number: ${pr_result.pr_number || pr_result.number || null}
  # If manual fallback (no PAT), still set pr_pending with null PR info
  if pr_result.fallback:
    invoke: state-management.update-initiative
    params:
      initiative_id: ${initiative.id}
      updates:
        phase_status:
          techplan:
            status: "pr_pending"
            pr_url: null
            pr_number: null

  output: |
    ✅ /techplan complete
    ├── Phase: TechPlan (techplan) finished
    ├── Audience: small
    ├── Artifacts: architecture.md, tech-decisions.md, api-contracts.md
    ├── Branch pushed: ${phase_branch}
    ├── PR: ${pr_result}
    ├── Status: pr_pending (awaiting merge)
    ├── Remaining on: ${phase_branch}
    └── Next: Once all small-audience phases are merged, run @lens next (or /devproposal).
```

### 7. Update State Files

```yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "techplan"
    phase_status:
      techplan:
        status: "in_progress"
        started_at: "${ISO_TIMESTAMP}"

invoke: state-management.update-state
params:
  updates:
    current_phase: "techplan"
    workflow_status: "pr_pending"
    active_branch: "${phase_branch}"
```

### 8. Commit State Changes

```yaml
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/lens-work/event-log.jsonl"
    - "${docs_path}/"
  message: "[lens-work] /techplan: TechPlan — ${initiative.id}"
  branch: "${phase_branch}"
```

### 9. Log Event

```json
{"ts":"${ISO_TIMESTAMP}","event":"techplan","id":"${initiative.id}","phase":"techplan","audience":"small","workflow":"techplan","status":"complete"}
```

### 10. Offer Next Step

```
Ready to continue?

**[C]** Continue to /devproposal (DevProposal phase)
**[P]** Pause here (resume later with @lens /devproposal)
**[S]** Show status (@lens ST)
```

### Step 10: Check Promotion Readiness

Execute the promotion-check include from `_bmad/lens-work/workflows/includes/promotion-check.md`:

```yaml
invoke: include
path: "_bmad/lens-work/workflows/includes/promotion-check.md"
params:
  current_phase: "techplan"
  initiative_root: "${initiative.id}"
  current_audience: "small"
  lifecycle_contract: load("lifecycle.yaml")
```

**Purpose:** Check if promotion to the next audience (medium) is available after techplan completion (since techplan has `auto_advance_promote: true` and `branching_audience: medium`). If all phases for the current audience are complete, offer the promote workflow.

---

## Error Handling

| Error | Action |
|-------|--------|
| BusinessPlan gate not passed | Block, suggest /businessplan |
| Previous phase PR not merged | Warn, allow override |
| Architecture doc empty | Warn, allow re-run |
| State write failure | Retry (max 3 attempts), then fail with save instructions |
| Dirty working directory | Prompt to stash or commit changes first |
| PR creation failed | `❌ HARD GATE: PR creation failed. Fix the issue and re-run.` |

---

## Post-Conditions

- [ ] Working directory clean (all changes committed)
- [ ] Phase branch `{initiative_root}-small-techplan` pushed to origin (REQ-7: no auto-merge)
- [ ] PR created from phase branch to audience branch
- [ ] Remaining on phase branch: `{initiative_root}-small-techplan`
- [ ] initiatives/{id}.yaml phase_status.techplan updated
- [ ] event-log.jsonl entry appended
- [ ] Architecture artifacts written to `${docs_path}/`
- [ ] All changes pushed to origin
