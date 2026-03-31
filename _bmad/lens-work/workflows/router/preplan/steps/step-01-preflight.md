---
name: 'step-01-preflight'
description: 'Run shared preflight, validate preplan eligibility, and mark phase start on initiative root branch'
nextStepFile: './step-02-select-workflows.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And Phase Start

**Goal:** Confirm the active initiative can run preplan, then mark the phase start on the initiative root branch with a commit marker and initiative-state update.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Resolve Initiative Context

```yaml
invoke: include
path: "{preflightInclude}"

invoke: git-orchestration.verify-clean-state

initiative_state = invoke: git-state.current-initiative
initiative = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

enabled_phases = lifecycle.tracks[initiative.track].phases || lifecycle.phase_order
if not contains(enabled_phases, "preplan"):
  FAIL("❌ Track `${initiative.track}` does not include preplan.")

initiative_root = initiative.initiative_root
output_path = initiative.docs.path || "{output_folder}/planning-artifacts"

# v3: Work directly on the initiative root branch — no phase branch creation
current_branch = invoke_command("git symbolic-ref --short HEAD")
if current_branch != initiative_root:
  invoke: git-orchestration.checkout-branch
  params:
    branch: ${initiative_root}

invoke: git-orchestration.pull-latest

ensure_directory(output_path)

# Mark phase start in initiative-state.yaml and commit the marker
invoke: git-orchestration.update-phase-start
params:
  phase: preplan

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${initiative_state.state_path}
  phase: "PHASE:PREPLAN:START"
  initiative: ${initiative_root}
  description: "preplan phase started"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`