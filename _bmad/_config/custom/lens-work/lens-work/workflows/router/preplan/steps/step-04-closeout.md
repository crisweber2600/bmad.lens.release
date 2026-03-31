---
name: 'step-04-closeout'
description: 'Commit preplan artifacts, update initiative state, and report the next command'
---

# Step 4: Close Out The PrePlan Phase

**Goal:** Commit the generated preplan artifacts with a phase-complete marker, update initiative state, and surface the next lifecycle command.

---

## EXECUTION SEQUENCE

### 1. Commit Artifacts And Mark Phase Complete

```yaml
# Commit preplan artifacts with phase-complete marker
# The commit body includes an inline artifact list per Decision OD-2
artifact_list = list_files(output_path)

# Update initiative-state.yaml: phase complete, record artifacts
invoke: git-orchestration.update-phase-complete
params:
  phase: preplan
  artifacts: ${artifact_list}

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${output_path}
    - ${initiative_state.state_path}
  phase: "PHASE:PREPLAN:COMPLETE"
  initiative: ${initiative.initiative_root}
  description: "preplan artifacts complete"
  commit_body: |
    Artifacts:
    ${artifact_list.join('\n    - ')}

invoke: git-orchestration.push

output: |
  ✅ /preplan complete
  ├── Branch: ${initiative.initiative_root} (initiative root)
  ├── Artifacts committed with [PHASE:PREPLAN:COMPLETE] marker
  └── Next: Run `/businessplan` to continue planning.
```