---
name: 'step-02-select-mode'
description: 'Capture the techplan execution mode and whether API contracts are in scope'
nextStepFile: './step-03-run-workflows.md'
---

# Step 2: Select The TechPlan Run Profile

**Goal:** Decide whether techplan runs in batch or interactive mode and whether API contracts should be generated in the current pass.

---

## EXECUTION SEQUENCE

### 1. Capture Mode And API Scope

```yaml
ask: "Execution mode? [interactive/batch]"
capture: execution_mode

ask: "Does this initiative require API contracts in this pass? [yes/no]"
capture: api_contract_choice

include_api_contracts = lower(api_contract_choice || "no") == "yes"

if execution_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "techplan"
    display_name: "TechPlan"
    template_path: "templates/techplan-questions.template.md"
    output_filename: "techplan-questions.md"
    scope: "phase"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`