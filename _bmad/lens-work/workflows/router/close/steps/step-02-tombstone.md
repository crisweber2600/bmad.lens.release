---
name: 'step-02-tombstone'
description: 'Generate rich tombstone markdown and publish to governance'
nextStepFile: './step-03-closeout.md'
---

# Step 2: Generate and Publish Tombstone

**Goal:** Generate a rich tombstone document and publish it to governance via direct push.

---

## EXECUTION SEQUENCE

### 1. Publish Tombstone To Governance

```yaml
tombstone_result = invoke: git-orchestration.publish-tombstone
params:
  initiative: ${initiative}
  domain: ${domain}
  service: ${service}
  close_state: ${close_state}
  superseded_by: ${superseded_by}
  reason: ${close_reason}
```

### 2. Report Tombstone Result

```yaml
if tombstone_result.status == "published":
  output: |
    ✅ Tombstone published to governance
    ├── Path: ${tombstone_result.target_path}
    └── Close state: ${tombstone_result.close_state}

else:
  output: |
    ⚠️ Tombstone publication skipped (${tombstone_result.reason})
    └── Initiative will still be closed locally
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
