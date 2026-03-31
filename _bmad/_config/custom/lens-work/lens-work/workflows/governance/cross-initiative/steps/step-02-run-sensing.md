---
name: 'step-02-run-sensing'
description: 'Run the sensing skill against the current initiative scope'
nextStepFile: './step-03-resolve-gate.md'
---

# Step 2: Run The Sensing Scan

**Goal:** Produce the overlap report for the current initiative scope using the sensing skill contract.

---

## EXECUTION SEQUENCE

### 1. Invoke Sensing

```yaml
sensing_scan_result = invoke: sensing.scan-initiatives
params:
  current_domain: ${initiative_config.domain}
  current_service: ${initiative_config.scope == "domain" ? null : initiative_config.service}
  current_feature: ${initiative_config.scope == "feature" ? initiative_config.feature : null}
  current_scope: ${initiative_config.scope}

sensing_report = sensing_scan_result.sensing_report || sensing_scan_result

output: |
  ✅ Sensing scan complete
  ├── Initiatives scanned: ${sensing_report.total_initiatives_scanned || 0}
  └── Overlaps: ${(sensing_report.overlaps || []).length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`