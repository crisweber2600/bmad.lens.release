---
name: 'step-03-resolve-gate'
description: 'Resolve the sensing gate mode from the effective constitution'
nextStepFile: './step-04-render-result.md'
---

# Step 3: Resolve The Sensing Gate Mode

**Goal:** Determine whether overlaps are advisory or hard-gated for the current initiative.

---

## EXECUTION SEQUENCE

### 1. Resolve Constitution Gate Mode

```yaml
constitution_result = invoke: constitution.resolve-constitution
params:
  domain: ${initiative_config.domain}
  service: ${initiative_config.service}
  repo: ${initiative_config.repo || null}
  language: ${initiative_config.language || null}

resolved_constitution = constitution_result.resolved_constitution || constitution_result
gate_mode = resolved_constitution.sensing_gate_mode || "informational"

sensing_result = {
  report: sensing_report,
  gate_mode: gate_mode,
  has_overlaps: (sensing_report.overlaps || []).length > 0,
  blocks_promotion: gate_mode == "hard" and (sensing_report.overlaps || []).length > 0
}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`