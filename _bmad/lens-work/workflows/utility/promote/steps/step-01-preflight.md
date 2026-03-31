---
name: 'step-01-preflight'
description: 'Run shared preflight and resolve the current promotion context'
nextStepFile: './step-02-route.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Promotion Context

**Goal:** Confirm the repo is ready for promotion and resolve the current initiative and audience tier.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Audience Resolution

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
audience_state = invoke: git-state.current-audience
current_audience = audience_state.audience || null

if initiative_state == null or initiative_state.initiative_root == null:
  FAIL("❌ Not on an initiative branch. Use `/switch` to select one first.")

output: |
  ✅ Promote alias ready
  ├── Initiative: ${initiative_state.initiative_root}
  └── Current audience: ${current_audience || "(none)"}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`