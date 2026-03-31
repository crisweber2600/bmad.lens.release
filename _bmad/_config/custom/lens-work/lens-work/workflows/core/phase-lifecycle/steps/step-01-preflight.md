---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize lifecycle state for the active phase'
nextStepFile: './step-02-validate-completion.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And Lifecycle Context

**Goal:** Load the active initiative and lifecycle contract, then resolve the source and target branches for phase completion.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Context Load

```yaml
invoke: include
path: "{preflightInclude}"

initiative = load("_bmad-output/lens-work/initiatives/${inputs.initiative_id}.yaml")
lifecycle = load("{lifecycleContract}")

phase_name = inputs.phase_name
display_name = inputs.display_name
initiative_id = inputs.initiative_id

resolved_phase = lifecycle.phases[phase_name]
audience = initiative.current_audience || resolved_phase.branching_audience || resolved_phase.audience
initiative_root = initiative.initiative_root
phase_branch = "${initiative_root}-${audience}-${phase_name}"
audience_branch = "${initiative_root}-${audience}"

output: |
  🔄 Phase lifecycle initialized
  ├── Initiative: ${initiative_root}
  ├── Phase: ${phase_name}
  ├── Source branch: ${phase_branch}
  └── Target branch: ${audience_branch}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`