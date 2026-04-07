---
name: 'step-02-resume'
description: 'Clear pause state, re-sense, and report'
---

# Step 2: Resume And Re-Sense

**Goal:** Clear pause metadata from `initiative-state.yaml`, run a quick sensing pass, and recommend the next action.

---

## EXECUTION SEQUENCE

### 1. Show Pause Summary

```yaml
output: |
  ## 🔄 Resuming Initiative

  | Field | Value |
  |-------|-------|
  | Initiative | ${current_initiative_root} |
  | Paused at | ${paused_at} |
  | Paused phase | ${paused_phase} |
  | Reason | ${pause_reason} |
```

### 2. Clear Pause State

```yaml
state_file = "{current_initiative_root}/initiative-state.yaml"

update_yaml(state_file, "status", "active")
update_yaml(state_file, "phase", paused_phase)
update_yaml(state_file, "milestone", paused_milestone)
remove_yaml(state_file, "paused_at")
remove_yaml(state_file, "paused_phase")
remove_yaml(state_file, "paused_milestone")
remove_yaml(state_file, "pause_reason")

# Add resume to history
append_yaml(state_file, "history", {
  event: "resumed",
  from_paused_at: paused_at,
  phase: paused_phase,
  timestamp: now_iso8601()
})
```

### 3. Re-Sense (Advisory)

```yaml
output: "🔍 Running cross-initiative sensing to detect changes during pause..."

sensing_result = invoke: cross-initiative.scan
  initiative_root: current_initiative_root

if sensing_result.conflicts and len(sensing_result.conflicts) > 0:
  output: |
    ⚠️ **Sensing detected ${len(sensing_result.conflicts)} potential overlap(s)** that arose while paused.
    Review with `/sense` for details.
else:
  output: "✅ No new cross-initiative conflicts detected."
```

### 4. Commit And Report

```yaml
invoke_command("git add '{state_file}'")
invoke_command("git commit -m 'resume: {current_initiative_root} at phase {paused_phase}'")

# Derive next action
next_action = invoke_command("./lens.core/_bmad/lens-work/scripts/derive-next-action.sh '{current_initiative_root}' --json")
  | parse_json

output: |
  ## ▶️ Initiative Resumed

  | Field | Value |
  |-------|-------|
  | Initiative | ${current_initiative_root} |
  | Phase | ${paused_phase} |
  | Milestone | ${paused_milestone} |
  | Next | ${next_action.next_command || next_action.gate_message} |

  Run `/next` or `/${paused_phase}` to continue.
```

---

## WORKFLOW COMPLETE
