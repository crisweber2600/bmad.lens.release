---
name: 'step-01-preflight'
description: 'Run pre-flight, validate devproposal prerequisite via initiative-state.yaml, and artifact checklist gating'
nextStepFile: './step-02-readiness.md'
preflightInclude: '../../includes/preflight.md'
lifecycleContract: '{project-root}/_bmad/lens-work/lifecycle.yaml'
---

# Step 1: Pre-Flight And Gate Checks

## STEP GOAL:

Confirm the devproposal prerequisite is met via `initiative-state.yaml`, detect missing required artifacts, and commit the phase start marker.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Stop immediately when a hard gate fails.
- Keep all branch and state decisions grounded in initiative config and lifecycle data.

### Role Reinforcement:
- You are the LENS control-plane router.
- Protect milestone progression, branch discipline, and planning gate integrity.

### Step-Specific Rules:
- Load `{preflightInclude}` before SprintPlan-specific gating.
- Use `{lifecycleContract}` for lifecycle contract validation.
- Treat missing required artifacts as a warning gate that needs an explicit user decision.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Carry forward `initiative`, `initiative_root`, `docs_path`, `bmad_docs`, `current_branch`, and `missing`.
- Preserve any artifact-warning decision so later steps can mark `passed_with_warnings` when necessary.

## CONTEXT BOUNDARIES:
- Available context: active branch, initiative config, `{preflightInclude}`, and `{lifecycleContract}`.
- Focus: prerequisite validation, artifact gating, and phase start marker.
- Limits: do not run readiness validation or sprint planning in this step.
- Dependencies: clean working tree and resolvable initiative state.

---

## MANDATORY SEQUENCE

### 1. Pre-Flight [REQ-9]

Load and execute `{preflightInclude}` first so authority-repo sync and constitutional bootstrap happen before SprintPlan routing logic.

Verify the working directory is clean, derive initiative state from the active branch, and load `{lifecycleContract}`.

Set `current_phase = sprintplan`, resolve `initiative_root`, `current_branch`, `docs_path`, `repo_docs_path`, `output_path`, and `bmad_docs`, and preserve the existing docs-path deprecation warning when initiative metadata is incomplete.

### 2. Validate Prerequisites Via Initiative State

Load `initiative-state.yaml` and verify devproposal phase is complete:

```yaml
state_yaml = load("initiative-state.yaml")
if state_yaml.phase_status.devproposal != "complete":
  FAIL("❌ DevProposal phase is not complete. Run `/devproposal` first.")
```

If DevProposal is not complete, stop with guidance to finish `/devproposal`.

### 3. Phase Start Marker

Commit the phase start marker on the current branch:

```yaml
invoke: git-orchestration.update-phase-start
params:
  initiative_id: ${initiative.id || initiative_root}
  phase: "sprintplan"
  branch: ${current_branch}
  commit_message: "[PHASE:SPRINTPLAN:START] Begin sprintplan on ${current_branch}"
```

### 4. Checklist Enforcement - Verify Required Artifacts

Verify the required planning artifacts exist at `{docs_path}`:
- Product Brief
- PRD
- Architecture
- Epics
- Stories
- Readiness Checklist

Collect missing artifacts into `missing`.

If any required artifacts are missing, display the list and ask whether to continue in warning mode. If the user declines, stop. If the user accepts, preserve that choice so later SprintPlan state can be marked `passed_with_warnings`.

### 5. Auto-Proceed

Display: "**Proceeding to readiness validation...**"

#### Menu Handling Logic:
- After preflight, prerequisite checks, and artifact gating complete, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no final menu.
- Stop only on hard prerequisite failures or when the user declines to continue past missing artifacts.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- DevProposal prerequisite is validated via initiative-state.yaml.
- `[PHASE:SPRINTPLAN:START]` marker is committed.
- Required planning artifacts are checked and any warning-mode decision is explicit.

### SYSTEM FAILURE:
- The working tree is dirty.
- DevProposal is incomplete.
- The user declines to continue with missing required artifacts.

**Master Rule:** Skipping steps is FORBIDDEN.