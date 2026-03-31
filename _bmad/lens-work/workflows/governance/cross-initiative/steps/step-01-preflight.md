---
name: 'step-01-preflight'
description: 'Run shared preflight and derive the initiative sensing context'
nextStepFile: './step-02-run-sensing.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Sensing Context

**Goal:** Confirm the repo is ready and derive the initiative scope values used by the sensing scan.

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

output: |
  ✅ Sensing context ready
  ├── Initiative: ${initiative_state.initiative_root}
  ├── Domain: ${initiative_config.domain}
  └── Service: ${initiative_config.service || "(none)"}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`