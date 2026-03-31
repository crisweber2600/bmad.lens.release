---
name: 'step-03-render-result'
description: 'Return the resolved constitution to the caller with a concise summary'
---

# Step 3: Return The Resolved Constitution

**Goal:** Provide the resolved constitution and a concise summary to any caller that needs it.

---

## EXECUTION SEQUENCE

### 1. Return The Result

```yaml
output: |
  ✅ Constitution resolved for ${resolution_context.domain}/${resolution_context.service}
  Repo scope: ${resolution_context.repo || "service-level"}
  Language scope: ${resolution_context.language || "default"}

return: ${resolved_constitution}
```