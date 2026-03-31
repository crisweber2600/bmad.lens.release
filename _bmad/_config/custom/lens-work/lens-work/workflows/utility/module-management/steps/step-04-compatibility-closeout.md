---
name: 'step-04-compatibility-closeout'
description: 'Summarize expected compatibility checks and close the module-management flow'
---

# Step 4: Compatibility And Closeout

**Goal:** Close the workflow with the expected compatibility checks and the final module-management outcome.

---

## EXECUTION SEQUENCE

### 1. Render Final Guidance

```yaml
if update_confirmed:
  output: |
    ✅ Module update guidance complete
    - Verify `module.yaml`, `lifecycle.yaml`, `module-help.csv`, and `README.md`
    - Check for renamed workflows or skill paths before replacing local module files
    - Re-run validation after the update if structural changes are expected
else:
  output: |
    ✅ Module management complete
    - Local version: ${local_version}
    - Release version: ${latest_version != null ? latest_version : "unavailable"}
```