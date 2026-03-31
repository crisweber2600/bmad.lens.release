---
name: 'step-05-report-context'
description: 'Reload initiative context after checkout and show the next suggested action'
---

# Step 5: Report The Switched Context

**Goal:** Confirm the checked-out initiative, reload its config, and point the user to the best follow-up action.

---

## EXECUTION SEQUENCE

### 1. Reload Initiative Context And Render Response

```yaml
initiative_config = invoke: git-state.initiative-config
params:
  root: ${target_root}

output: |
  ✅ Switched to initiative `${target_root}`
  🏷️ Track: ${initiative_config.track || "(not set)"}
  👥 Audience: ${initiative_config.current_audience || "small"}
  📋 Phase: ${initiative_config.current_phase || "(not started)"}

  ▶️ Run `/next` for the recommended next lifecycle action.
```