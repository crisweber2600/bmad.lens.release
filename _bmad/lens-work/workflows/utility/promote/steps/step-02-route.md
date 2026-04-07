---
name: 'step-02-route'
description: 'Exit at the final audience or delegate to core audience-promotion'
---

# Step 2: Route To Core Promotion

**Goal:** Stop cleanly when no further promotion exists, otherwise hand off to the core audience-promotion workflow.

---

## EXECUTION SEQUENCE

### 0. Check Topology (v3.4)

```yaml
# 2-branch topology uses plan→root PR instead of audience promotion
if session.feature_yaml_context != null and session.feature_yaml_context.enabled == true:
  topology = session.feature_yaml_context.topology  # "2-branch"
  plan_branch = session.feature_yaml_context.plan_branch
  root_branch = initiative_state.initiative_root

  output: |
    🔀 **2-Branch Topology** — This initiative uses a plan→root PR model.

    Milestone and audience promotion are not applicable.

    **Next action:** When planning is complete on `${plan_branch}`, create a PR from `${plan_branch}` → `${root_branch}` to consolidate all planning artifacts.

    Use `/close` when the initiative is ready to finalize.
  exit: 0
```

### 1. Exit Or Route

```yaml
audience_chain = ["small", "medium", "large", "base"]
audience_index = index_of(audience_chain, current_audience)
next_audience = audience_index >= 0 and audience_index < audience_chain.length - 1 ? audience_chain[audience_index + 1] : null

if current_audience == null:
  FAIL("❌ No audience token found on the current branch.")

if next_audience == null:
  output: "✅ Initiative is at the final audience — no promotion available."
else:
  output: "▶️ Routing `/promote` to the core audience-promotion workflow."
  invoke: workflow
  path: "../../../core/audience-promotion/workflow.md"
```