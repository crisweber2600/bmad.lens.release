---
name: 'step-03-execute-or-report'
description: 'Render the next-action context header and execute or report the selected outcome'
---

# Step 3: Execute Or Report

**Goal:** Present the lifecycle context clearly, then either invoke the next workflow immediately or stop on the correct gate message.

---

## EXECUTION SEQUENCE

### 1. Render Context And Outcome

```yaml
if current_row != null:
  output: |
    📂 Initiative: ${current_row.initiative}
    🏷️ Track: ${current_row.track || "(not set)"}
    👥 Audience: ${current_row.audience || "-"}
    📋 Phase: ${current_row.phase || "-"}

if hard_gate == true or next_command == null:
  output: ${gate_message}
else:
  output: "▶️ Executing `${next_command}`..."
  invoke_command: "@lens ${next_command}"
```