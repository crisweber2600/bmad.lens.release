---
name: preplan
description: Launch PrePlan phase (brainstorm/research/product brief)
agent: "@lens"
trigger: /preplan command
aliases: [/pre-plan]
category: router
phase_name: preplan
display_name: PrePlan
agent_owner: mary
agent_role: Analyst
imports: lifecycle.yaml
---

# /preplan — PrePlan Phase Router

**Purpose:** Guide users through the PrePlan phase, invoking brainstorming, research, and product brief workflows.

**Lifecycle:** `preplan` phase, audience `small`, owned by Mary (Analyst).

---

## User Interaction Keywords

This workflow supports special keywords to control prompting behavior:

- **"defaults" / "best defaults"** → Apply defaults to **CURRENT STEP ONLY**; resume normal prompting for subsequent steps
- **"yolo" / "keep rolling"** → Apply defaults to **ENTIRE REMAINING WORKFLOW**; auto-complete all steps
- **"all questions" / "batch questions"** → Present **ALL QUESTIONS UPFRONT** → wait for batch answers → follow-up questions → adversarial review → final questions → generate artifacts
- **"skip"** → Jump to a named optional step (e.g., "skip to product brief")
- **"pause"** → Halt workflow, save progress, resume later
- **"back"** → Roll back to previous step, re-answer questions

**Critical Rule:**
- "defaults" applies only to the current question/step
- "yolo" applies to all remaining steps in the workflow
- "all questions" presents comprehensive questionnaire, then iteratively refines with follow-ups and party mode review
- Other workflows and phases are unaffected

---

## Prerequisites

- [x] Initiative created via `#new-*` command
- [x] Layer detected with confidence ≥ 75%
- [x] Initiative file exists at `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`

---

## Execution Sequence

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Phase Router Validation + Branch

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `preplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Validate no predecessor is required (preplan is always the first phase)
4. If valid: create phase branch `{initiative-root}-small-preplan` using git-orchestration
5. If track doesn't include preplan: report error with valid phases for this track

### Step 2: Load Initiative Context

Load the initiative config from `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`:

- Initiative root, domain, service, feature
- Track type and enabled phases
- Any previous artifacts from earlier sessions

Derive output path for artifacts:
```yaml
output_path = "_bmad-output/lens-work/initiatives/{domain}/{service}/phases/preplan/"
ensure_directory(output_path)
```

### Step 2a: Workflow & Mode Selection

Present workflow selection and execution mode together in a single prompt:

```
🧭 /preplan — PrePlan Phase

You're starting the Analysis phase. Available workflows:

**[1] Brainstorming** (optional) — Creative exploration with CIS
**[2] Research** (optional) — Deep dive research with CIS
**[3] Product Brief** (required) — Define problem, vision, and scope

Recommended path: 1 → 2 → 3 (or skip to 3 if you have clarity)

Select workflow(s) to run: [1] [2] [3] [A]ll [S]kip to Product Brief

📋 Execution Mode:
**[I] Interactive** — Answer step-by-step
**[B] Batch**       — Answer all questions at once
(Default: Interactive)
```

**⚠️ Brainstorming is ALWAYS interactive.** If the user selects batch mode and brainstorming:
- Run brainstorming interactively first
- Then switch to batch mode for the remaining workflows (research, product brief)

If batch mode selected (without brainstorming), invoke batch-process and exit.
Otherwise continue to Step 3 for interactive execution.

### Step 3: Execute Selected Workflows

**⚠️ CRITICAL — Interactive Workflow Rules:**
Each sub-workflow uses sequential step-file architecture.
- 🛑 **NEVER** auto-complete or batch-generate content without user input
- ⏸️ **ALWAYS** STOP and wait for user input/confirmation at each step
- 🚫 **NEVER** load the next step file until user explicitly confirms (Continue / C)
- 📋 Back-and-forth dialogue is REQUIRED — you are a facilitator, not a generator
- 💾 Save/update frontmatter after completing each step before loading the next
- 🎯 Read the ENTIRE step file before taking any action within it

**⚠️ Brainstorming is ALWAYS interactive** — even when the user selected batch mode.
If batch mode was chosen alongside brainstorming, run brainstorming interactively first,
then switch to batch for the remaining workflows.

**Agent:** Adopt Mary (Analyst) persona — load `_bmad/bmm/agents/analyst.md`

#### If Brainstorming selected:

```yaml
# Read fully and follow this workflow file:
#   _bmad/core/workflows/brainstorming/workflow.md
# Uses step-file architecture with steps/ folder — load step-01-session-setup.md first
# STOP and wait for user at each step — do NOT auto-generate brainstorm content
read_and_follow: "_bmad/core/workflows/brainstorming/workflow.md"
params:
  context: "${initiative.name} at ${initiative.layer} layer"
```

#### If Research selected:

```yaml
# Ask user for research type, then follow the correct workflow:
#   Market:    _bmad/bmm/workflows/1-analysis/research/workflow-market-research.md
#   Domain:    _bmad/bmm/workflows/1-analysis/research/workflow-domain-research.md
#   Technical: _bmad/bmm/workflows/1-analysis/research/workflow-technical-research.md
# Each uses step-file architecture — load steps one at a time, wait for user at each step
prompt_user: "Which type of research? [M]arket / [D]omain / [T]echnical"
if research_type == "market":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-market-research.md"
elif research_type == "domain":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-domain-research.md"
elif research_type == "technical":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-technical-research.md"
```

#### Product Brief (always):

```yaml
# Read fully and follow this workflow file:
#   _bmad/bmm/workflows/1-analysis/create-product-brief/workflow.md
# Uses JIT step-file architecture:
#   1. Load step-01-init.md first
#   2. Only load next step when directed by the current step
#   3. NEVER load multiple step files simultaneously
#   4. ALWAYS halt at menus and wait for user input
#   5. Output goes to: ${output_path}/product-brief.md
# Agent persona: Mary (Analyst) — _bmad/bmm/agents/analyst.md
read_and_follow: "_bmad/bmm/workflows/1-analysis/create-product-brief/workflow.md"
params:
  output_path: "${output_path}/"
  context:
    brainstorm_notes: "${output_path}/brainstorm-notes.md"   # if exists from step [1]
    research_summary: "${output_path}/research-summary.md"   # if exists from step [2]
```

### Step 4: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/preplan/`
2. Commit with message: `[PREPLAN] {initiative-root} — preplan artifacts complete`
3. Push to remote (reviewable checkpoint)

### Step 5: Phase Completion

> **⛔ MANDATORY EPILOGUE — NEVER SKIP**
> Steps 5–8 below MUST execute after artifact generation completes,
> regardless of how artifacts were produced (interactive, batch, YOLO, or
> recovery from interruption). Committing artifacts without creating the
> PR leaves the phase in a broken state. If you have committed and pushed
> artifacts, you are NOT done — continue executing from this point.

```yaml
if all_workflows_complete("preplan"):
  # Push final state to phase branch
  invoke: git-orchestration.commit-and-push
  params:
    branch: ${phase_branch}
    message: "[${initiative.id}] PrePlan complete"
  # Phase branch remains alive — PR handles merge to audience branch

  # REQ-8: Create PR for phase merge using create-pr script (PAT + API, no gh CLI)
  invoke: script
  script: "${PROJECT_ROOT}/_bmad/lens-work/scripts/create-pr.ps1"  # or .sh on Unix
  params:
    SourceBranch: ${phase_branch}
    TargetBranch: ${audience_branch}
    Title: "[PHASE] ${initiative.id} — PrePlan complete"
    Body: "PrePlan phase complete for ${initiative.id}.\n\nPhase: preplan\nAudience: small\nArtifacts: product-brief.md\n\n---\n*Generated by lens-work/workflows/router/preplan*"
  capture: pr_result  # { Url, Number } from script output

  # REQ-7/REQ-8: Phase enters pr_pending after PR creation
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      phase_status:
        preplan:
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
          preplan:
            status: "pr_pending"
            pr_url: null
            pr_number: null

  output: |
    ✅ /preplan complete
    ├── Phase: PrePlan (preplan) finished
    ├── Audience: small
    ├── Artifacts: product-brief.md (+ brainstorm/research if produced)
    ├── Branch pushed: ${phase_branch}
    ├── PR: ${pr_result}
    ├── Status: pr_pending (awaiting merge)
    ├── Remaining on: ${phase_branch}
    └── Next: Run /businessplan to continue to BusinessPlan phase
```

### Step 6: Update State Files

```yaml
# Update initiative file: _bmad-output/lens-work/initiatives/${initiative.id}.yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "preplan"
    phase_status:
      preplan:
        status: "in_progress"
        started_at: "${ISO_TIMESTAMP}"

```

### Step 7: Commit State Changes

```yaml
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/lens-work/event-log.jsonl"
    - "${output_path}/"
  message: "[lens-work] /preplan: PrePlan — ${initiative.id}"
  branch: "${phase_branch}"
```

### Step 8: Log Event

```json
{"ts":"${ISO_TIMESTAMP}","event":"preplan","id":"${initiative.id}","phase":"preplan","audience":"small","workflow":"preplan","status":"complete"}
```

### Step 9: Offer Next Step

```
Ready to continue?

**[C]** Continue to /businessplan (BusinessPlan phase)
**[P]** Pause here (resume later with @lens /businessplan)
**[S]** Show status (@lens ST)
```

### Step 10: Check Promotion Readiness

Execute the promotion-check include from `_bmad/lens-work/workflows/includes/promotion-check.md`:

```yaml
invoke: include
path: "_bmad/lens-work/workflows/includes/promotion-check.md"
params:
  current_phase: "preplan"
  initiative_root: "${initiative.id}"
  current_audience: "small"
  lifecycle_contract: load("lifecycle.yaml")
```

**Purpose:** Check if promotion to the next audience is available after preplan completion. If all phases for the current audience are complete, offer the promote workflow. Otherwise, display pending phases.

---

## Output Artifacts

| Artifact | Location | Required |
|----------|----------|----------|
| Product Brief | `phases/preplan/product-brief.md` | Yes |
| Research Summary | `phases/preplan/research-summary.md` | If research selected |
| Brainstorm Notes | `phases/preplan/brainstorm-notes.md` | If brainstorming selected |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` | Yes |

---

## Error Handling

| Error | Response |
|-------|----------|
| Track doesn't include preplan | `❌ Track '{track}' does not include preplan. Valid phases: {phases}` |
| Not on initiative branch | `❌ Not on an initiative branch. Use /switch or /new-domain first.` |
| Already on a phase branch | `⚠️ Already on phase branch {branch}. Complete current phase first.` |
| Dirty working directory | Prompt to stash or commit changes first |
| Branch creation failed | Check remote connectivity, retry with backoff |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |
| PR creation failed | `❌ HARD GATE: PR creation failed. Fix the issue and re-run.` |

---

## Post-Conditions

- [ ] Working directory clean (all changes committed)
- [ ] Phase branch `{initiative_root}-small-preplan` pushed to origin (REQ-7: no auto-merge)
- [ ] PR created from phase branch to audience branch
- [ ] Remaining on phase branch: `{initiative_root}-small-preplan`
- [ ] initiatives/{id}.yaml phase_status.preplan updated
- [ ] event-log.jsonl entry appended
- [ ] Planning artifacts written to `${output_path}/` (at minimum product-brief.md)
- [ ] All changes pushed to origin
