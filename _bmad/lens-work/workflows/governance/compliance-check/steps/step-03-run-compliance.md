---
name: 'step-03-run-compliance'
description: 'Evaluate initiative artifacts against the resolved constitution'
nextStepFile: './step-04-render-result.md'
---

# Step 3: Run Constitutional Compliance

**Goal:** Execute the compliance check for the current phase and capture both hard-gate and informational failures.

---

## EXECUTION SEQUENCE

### 1. Invoke Constitution Compliance Check

```yaml
compliance_check_result = invoke: constitution.check-compliance
params:
  resolved_constitution: ${resolved_constitution}
  initiative_root: ${initiative_state.initiative_root}
  phase: ${current_phase}
  artifacts_path: ${artifacts_path}

compliance_result = compliance_check_result.compliance_result || compliance_check_result

output: |
  ✅ Compliance check complete
  ├── Status: ${compliance_result.status}
  ├── Hard-gate failures: ${(compliance_result.hard_gate_failures || []).length}
  └── Informational failures: ${(compliance_result.informational_failures || []).length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`