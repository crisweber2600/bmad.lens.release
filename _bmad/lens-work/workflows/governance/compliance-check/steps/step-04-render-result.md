---
name: 'step-04-render-result'
description: 'Render the compliance summary and stop on hard-gate failures'
---

# Step 4: Render The Compliance Result

**Goal:** Produce the PR-ready compliance summary and block the caller when hard-gate requirements are unresolved.

---

## EXECUTION SEQUENCE

### 1. Render Summary Or Hard-Gate Failure

```yaml
check_rows = map(compliance_result.checks || [], item -> "| " + item.requirement + " | " + item.status + " | " + item.details + " |")

if (compliance_result.hard_gate_failures || []).length > 0:
  output: |
    ❌ Constitution Compliance FAILED — PR cannot be created

    ${map(compliance_result.hard_gate_failures, item -> "- " + item).join("\n")}
  FAIL("❌ Hard-gate constitutional requirements are not satisfied.")

output: |
  ### Constitution Compliance

  | Requirement | Status | Details |
  |-------------|--------|---------|
  ${check_rows.join("\n")}

  **Overall:** ${compliance_result.status}
```