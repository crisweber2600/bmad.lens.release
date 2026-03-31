---
name: 'step-02-resolve-constitution'
description: 'Resolve the effective constitution for the current initiative'
nextStepFile: './step-03-run-compliance.md'
---

# Step 2: Resolve The Effective Constitution

**Goal:** Load the merged constitutional requirements for the current initiative context.

---

## EXECUTION SEQUENCE

### 1. Invoke Constitution Resolution

```yaml
resolved_constitution_result = invoke: constitution.resolve-constitution
params:
  domain: ${initiative_config.domain}
  service: ${initiative_config.service}
  repo: ${initiative_config.repo || null}
  language: ${initiative_config.language || null}

resolved_constitution = resolved_constitution_result.resolved_constitution || resolved_constitution_result

output: |
  ✅ Constitution resolved
  ├── Domain: ${initiative_config.domain}
  ├── Service: ${initiative_config.service || "(none)"}
  └── Levels loaded: ${(resolved_constitution.levels_loaded || []).join(', ')}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`