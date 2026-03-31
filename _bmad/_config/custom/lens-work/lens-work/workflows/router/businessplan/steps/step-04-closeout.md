---
name: 'step-04-closeout'
description: 'Commit businessplan artifacts, update initiative state, and report the next command'
---

# Step 4: Close Out The BusinessPlan Phase

**Goal:** Commit the generated businessplan artifacts with a phase-complete marker, update initiative state, and surface the next lifecycle command.

---

## EXECUTION SEQUENCE

### 1. Validate Artifacts, Commit, And Mark Phase Complete

```yaml
has_prd = file_exists("${docs_path}/prd.md")
has_ux = file_exists("${docs_path}/ux-design.md") or file_exists("${docs_path}/ux-design-specification.md")
has_architecture = file_exists("${docs_path}/architecture.md")

if not has_prd or not has_architecture:
  FAIL("❌ BusinessPlan phase incomplete. Required artifacts are missing from ${docs_path}.")

# Commit artifacts with phase-complete marker and inline artifact list
artifact_list = list_files(docs_path)

# Update initiative-state.yaml: phase complete, record artifacts
invoke: git-orchestration.update-phase-complete
params:
  phase: businessplan
  artifacts: ${artifact_list}

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${docs_path}
    - ${initiative_state.state_path}
  phase: "PHASE:BUSINESSPLAN:COMPLETE"
  initiative: ${initiative.initiative_root}
  description: "businessplan artifacts complete"
  commit_body: |
    Artifacts:
    ${artifact_list.join('\n    - ')}

invoke: git-orchestration.push

output: |
  ✅ /businessplan complete
  ├── Branch: ${initiative.initiative_root} (initiative root)
  ├── Artifacts committed with [PHASE:BUSINESSPLAN:COMPLETE] marker
  └── Next: Run `/techplan` to continue planning.
```