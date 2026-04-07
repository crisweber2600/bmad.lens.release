---
name: 'step-02-derive-action'
description: 'Apply lifecycle rules and choose the next command or hard gate'
nextStepFile: './step-03-execute-or-report.md'
---

# Step 2: Derive The Next Action

**Goal:** Apply the lifecycle decision rules in priority order and reduce the current initiative context to a single execution target or hard gate.

---

## EXECUTION SEQUENCE

### 1. Apply Lifecycle Rules

```yaml
next_command = null
gate_message = null
hard_gate = false

# v3.4: When feature.yaml state is available, use it for phase resolution
if session.feature_yaml_state != null and session.feature_yaml_state.available == true:
  feature_state = session.feature_yaml_state

  if feature_state.status == "complete" or feature_state.status == "archived":
    gate_message = "✅ This initiative is ${feature_state.status}. No further actions."
  else if feature_state.current_phase != null:
    next_command = "/" + feature_state.current_phase
  else:
    gate_message = "✅ All caught up. The initiative is ready for execution."

else if current_row == null:
  gate_message = "ℹ️ Not currently on an initiative branch. Run `/status` or `/switch`."
else if current_row.audience == null and current_context.scope == "domain":
  next_command = "/new-service"
else if current_row.audience == null and current_context.scope == "service":
  next_command = "/new-feature"
else if contains(current_row.action, "Awaiting review") or contains(current_row.action, "Awaiting merge"):
  hard_gate = true
  gate_message = "⏳ A PR is still open for the active lifecycle step. Merge it, then run `/next` again."
else if contains(current_row.action, "Address review feedback"):
  hard_gate = true
  gate_message = "⛔ Review feedback is blocking progress. Resolve the requested changes, then run `/next` again."
else if current_row.action == "Ready to promote" or current_row.action == "Promotion in review":
  next_command = current_row.action == "Ready to promote" ? "/promote" : null
  if current_row.action == "Promotion in review":
    hard_gate = true
    gate_message = "⏳ Promotion PR is open. Merge it, then run `/next` again."
else if current_row.phase != null and (current_row.action == "Complete phase" or current_row.action == "Start next phase"):
  next_command = "/" + current_row.phase
else if current_row.action == "Ready for execution":
  gate_message = "✅ All caught up. The initiative is ready for execution."
else:
  gate_message = "ℹ️ No deterministic next action was found. Run `/status` for the full picture."
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`