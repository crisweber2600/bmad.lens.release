---
name: 'step-04-cleanup'
description: 'Clean up merged phase branches safely and close the workflow response'
---

# Step 4: Safe Cleanup

**Goal:** Delete stale phase branches only when the corresponding PR is merged, then close with a concise lifecycle summary.

---

## EXECUTION SEQUENCE

### 1. Verify Merge State Before Cleanup

```yaml
pr_status = invoke: git-orchestration.query-pr-status
params:
  head: ${phase_branch}
  base: ${audience_branch}

if pr_status.state == "merged" and branch_exists(phase_branch):
  invoke: git-orchestration.delete-branch
  params:
    branch: ${phase_branch}
    delete_remote: true
  output: "🧹 Cleaned up merged phase branch `${phase_branch}`"
else:
  output: "Phase branch cleanup skipped. Merge has not been confirmed yet."
```

### 2. Final Response

```yaml
if lifecycle.phases[phase_name].auto_advance_promote == true:
  output: |
    ✅ Phase lifecycle closeout complete
    ├── PR state: ${pr_status.state || "unknown"}
    ├── Phase branch: ${phase_branch}
    └── Next command: ${lifecycle.phases[phase_name].auto_advance_to}

    If promotion-check did not offer `/promote`, continue with `${lifecycle.phases[phase_name].auto_advance_to}` after the PR merge settles.
else:
  output: |
    ✅ Phase lifecycle closeout complete
    ├── PR state: ${pr_status.state || "unknown"}
    ├── Phase branch: ${phase_branch}
    └── Next command: ${lifecycle.phases[phase_name].auto_advance_to}

    Use `${lifecycle.phases[phase_name].auto_advance_to}` after the PR is merged when the next phase is ready.
```