---
name: 'step-01-preflight'
description: 'Run shared preflight and derive initiative compliance context'
nextStepFile: './step-02-resolve-constitution.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Compliance Context

**Goal:** Confirm the repo is ready, then derive the initiative, phase, and artifacts path the compliance check should evaluate.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Context Resolution

```yaml
invoke: include
path: "{preflightInclude}"
params:
  skip_constitution: true

initiative_state = invoke: git-state.current-initiative
initiative_config = load(initiative_state.config_path)
phase_state = invoke: git-state.current-phase

current_phase = inputs.phase || phase_state.phase || initiative_config.current_phase || ""
artifacts_path = inputs.artifacts_path || initiative_config.docs.path || "{output_folder}/planning-artifacts"

if current_phase == "":
  FAIL("❌ Compliance check needs an active phase or an explicit phase input.")

output: |
  ✅ Compliance context ready
  ├── Initiative: ${initiative_state.initiative_root}
  ├── Phase: ${current_phase}
  └── Artifacts: ${artifacts_path}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`