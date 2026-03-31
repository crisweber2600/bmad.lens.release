---
name: 'step-02-resolve'
description: 'Invoke constitution resolution using the derived initiative context'
nextStepFile: './step-03-render-result.md'
---

# Step 2: Resolve The Constitution

**Goal:** Resolve the effective constitution from the initiative governance hierarchy.

---

## EXECUTION SEQUENCE

### 1. Invoke Constitution Resolution

```yaml
resolved_constitution = invoke: constitution.resolve-constitution
params:
  domain: ${resolution_context.domain}
  service: ${resolution_context.service}
  repo: ${resolution_context.repo}
  language: ${resolution_context.language}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`