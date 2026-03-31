---
name: 'step-01-preflight'
description: 'Run shared preflight and gather the internal status snapshot'
nextStepFile: './step-02-derive-action.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And Status Snapshot

**Goal:** Confirm the control repo is ready, then gather the lifecycle status snapshot `/next` uses to choose a single action.

---

## EXECUTION SEQUENCE

### 1. Preflight And Status Capture

```yaml
invoke: include
path: "{preflightInclude}"

lifecycle = load("{lifecycleContract}")
current_context = invoke: git-state.current-initiative
status_snapshot = invoke: workflow
path: "../../status/workflow.md"
params:
  detail_initiative: ${current_context.initiative_root || ""}

current_row = first(status_snapshot.detail_rows) || first(status_snapshot.status_rows)

output: |
  ✅ Next-action context loaded
  ├── Current initiative: ${current_context.initiative_root || "(none)"}
  └── Status rows: ${(status_snapshot.status_rows || []).length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`