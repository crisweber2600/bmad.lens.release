---
name: 'step-01-preflight'
description: 'Run dev pre-flight, resolve the target repo, and validate the large-to-base promotion gate'
nextStepFile: './step-02-story-discovery.md'
preflightInclude: '../../includes/preflight.md'
promotionAndContextData: '../data/preflight-promotion-and-context.md'
---

# Step 1: Pre-Flight And Target Repo Validation

## STEP GOAL:

Establish the `/dev` branch context, resolve the implementation target repo, and confirm SprintPlan and promotion gates before story execution begins.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Keep control-plane operations in the BMAD repo unless this step explicitly switches to the TargetProject repo.
- Stop immediately when a hard gate fails.

### Role Reinforcement:
- You are the LENS control-plane router.
- Protect authority boundaries, branch discipline, and constitutional enforcement.

### Step-Specific Rules:
- NEVER allow `/dev` to target `bmad.lens.release`.
- Resolve initiative context from git-derived state, not ad hoc assumptions.
- Load `{preflightInclude}` before applying any dev-specific gate logic.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Carry forward `initiative`, `docs_path`, `bmad_docs`, `phase_branch`, `constitutional_context`, `session.target_repo`, and `session.target_path`.
- Load `{promotionAndContextData}` completely before applying its checks.

## CONTEXT BOUNDARIES:
- Available context: active git branch, initiative config, lifecycle state, `{preflightInclude}`, and `{promotionAndContextData}`.
- Focus: branch setup, target repo resolution, prior-phase validation, and large-to-base promotion enforcement.
- Limits: do not begin story implementation in this step.
- Dependencies: clean working tree and valid initiative state.

---

## MANDATORY SEQUENCE

### 1. Pre-Flight [REQ-9]

Load and execute `{preflightInclude}` first so authority-repo sync and constitutional bootstrap happen before any `/dev` routing logic.

Verify the working directory is clean, derive the active initiative from the current branch, and load the initiative configuration.

Set the `/dev` audience context to `base`, resolve `initiative_root`, derive `phase_branch = {initiative_root}-dev`, and resolve `docs_path`, `repo_docs_path`, and `bmad_docs` from initiative metadata.

If `initiative.docs.path` is missing, fall back to `_bmad-output/planning-artifacts/`, clear `repo_docs_path`, and surface the existing deprecation warning.

Resolve the target repository from `initiative.target_repos[0]`. If no target repo is configured, ask the user for a local repository path, require a non-empty answer, and store the result in `session.target_repo` and `session.target_path`.

Display the resolved target repository. If the resolved path points into `bmad.lens.release`, fail immediately because `/dev` may only write inside the TargetProject repository.

If initiative-specific docs exist, load architecture and stories context when available. Otherwise continue without planning context.

Ensure `{phase_branch}` exists through `git-orchestration.start-phase` when needed, then check it out, pull the latest remote state, and confirm the branch to the user.

### 2. Promotion, Constitutional Context, And Branch Verification

Load and apply `{promotionAndContextData}` in the active `/dev` pre-flight context. This reference contains the remaining hard-gate logic for this step and must be followed completely. It is responsible for:

- large-to-base promotion verification
- prior SprintPlan completion handling
- constitutional context injection
- final branch assertion

### 3. Auto-Proceed

Display: "**Proceeding to story discovery...**"

#### Menu Handling Logic:
- After successful preflight and gate checks, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Stop only if target repo resolution is cancelled or a hard gate fails.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- `/dev` phase branch is ready and checked out.
- `session.target_repo` and `session.target_path` are resolved and safe.
- Prior-phase, promotion, and constitutional checks have been applied.

### SYSTEM FAILURE:
- The working tree is dirty.
- The target repo is missing, empty, or resolves into `bmad.lens.release`.
- Prior-phase or promotion gates fail.
- The `/dev` phase branch cannot be created or checked out.

**Master Rule:** Skipping steps is FORBIDDEN.