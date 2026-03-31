---
name: 'step-02-resolve-target'
description: 'Resolve the switch target from the initiative inventory'
nextStepFile: './step-03-handle-dirty-state.md'
---

# Step 2: Resolve The Initiative Target

**Goal:** Determine the initiative root to switch to, prompting only when the user did not provide one.

---

## EXECUTION SEQUENCE

### 1. Discover Initiative Roots

```yaml
initiative_inventory = invoke: git-state.active-initiatives
initiative_roots = unique(map(initiative_inventory.initiatives, item -> item.root))

if initiative_roots == null or initiative_roots.length == 0:
  output: "ℹ️ No active initiatives found. Run `/new-domain` or `/new-service` to create one."
  exit: 0

if target_root == "":
  output: |
    📋 Active initiatives:
    ${map(initiative_roots, item -> "- " + item).join("\n")}
  ask: "Which initiative root should /switch check out?"
  capture: target_root

if not contains(initiative_roots, target_root):
  FAIL("❌ Initiative `${target_root}` was not found. Run `/status` to inspect the available initiatives.")
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`