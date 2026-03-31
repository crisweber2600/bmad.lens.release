---
name: 'step-01-preflight'
description: 'Run preflight, resolve the active initiative, and determine the current and next audiences'
nextStepFile: './step-02-run-gates.md'
preflightInclude: '../../includes/preflight.md'
lifecycleContract: '../../../lifecycle.yaml'
---

# Step 1: Preflight And Audience Resolution

**Goal:** Confirm the current branch belongs to an initiative, resolve the current audience, and determine whether a next audience exists.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Resolve Promotion Context

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
initiative_config = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

current_audience = invoke: git-state.current-audience
next_audience = lifecycle.audiences[current_audience].next || ""

if next_audience == "":
  output: "✅ Initiative is already at the final audience. No promotion is available."
  exit: 0

initiative_root = initiative_config.initiative_root
source_branch = "${initiative_root}-${current_audience}"
target_branch = "${initiative_root}-${next_audience}"
gate_failures = []
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`