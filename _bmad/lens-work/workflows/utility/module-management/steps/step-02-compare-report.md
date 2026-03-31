---
name: 'step-02-compare-report'
description: 'Compare local and release versions and report update status'
nextStepFile: './step-03-update-guidance.md'
---

# Step 2: Compare And Report Module Versions

**Goal:** Tell the user whether the installed module is current, outdated, or unable to reach release metadata.

---

## EXECUTION SEQUENCE

### 1. Determine Update Availability

```yaml
update_available = latest_version != null and latest_version != "unknown" and latest_version != local_version

if latest_version == null:
  output: |
    📦 Module: lens-work v${local_version}
    ⚠️ Could not check for updates — release repo not accessible
else if update_available:
  output: |
    📦 Module: lens-work v${local_version}
    ⚠️ Update available: ${local_version} → ${latest_version}
else:
  output: |
    📦 Module: lens-work v${local_version}
    ✅ Module is up to date
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`