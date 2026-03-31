---
name: 'step-03-closeout'
description: 'Update initiative-state.yaml with close state and commit the close marker'
---

# Step 3: Update State and Commit Close Marker

**Goal:** Atomically update initiative-state.yaml with the terminal close state and commit the close marker.

---

## EXECUTION SEQUENCE

### 1. Update Initiative State

```yaml
invoke: git-orchestration.update-close
params:
  close_state: ${close_state}
  superseded_by: ${superseded_by}
  reason: ${close_reason}
```

### 2. Report Final Close Status

```yaml
output: |
  ✅ Initiative Closed
  ├── Initiative: ${initiative}
  ├── Close State: ${close_state}
  ├── Superseded By: ${superseded_by || 'N/A'}
  ├── Reason: ${close_reason}
  ├── Commit Marker: [CLOSE:${close_state.toUpperCase()}] ${initiative} — ${close_reason}
  ├── Tombstone: ${tombstone_result.status == "published" ? tombstone_result.target_path : "skipped"}
  └── initiative-state.yaml: lifecycle_status = ${close_state}

  The initiative is now formally closed. Branches may be cleaned up manually.
```
