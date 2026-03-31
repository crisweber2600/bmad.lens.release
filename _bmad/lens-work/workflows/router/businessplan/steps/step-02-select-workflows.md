---
name: 'step-02-select-workflows'
description: 'Capture the businessplan execution mode and workflow selection'
nextStepFile: './step-03-run-workflows.md'
---

# Step 2: Select BusinessPlan Workflows

**Goal:** Decide whether businessplan runs in batch or interactive mode and capture which planning workflows the user wants to execute.

---

## EXECUTION SEQUENCE

### 1. Capture Mode And Workflow Selection

```yaml
ask: "Execution mode? [interactive/batch]"
capture: execution_mode

output: |
  🧭 /businessplan

  Available workflows:
  - PRD (required)
  - UX Design (optional when UI is involved)
  - Architecture (required)

ask: "Which workflows should run? Use prd, ux, architecture, or all."
capture: workflow_selection

selected_workflows = workflow_selection == "all" ? ["prd", "ux", "architecture"] : contains(workflow_selection, "ux") ? ["prd", "ux", "architecture"] : ["prd", "architecture"]

if execution_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "businessplan"
    display_name: "BusinessPlan"
    template_path: "templates/businessplan-questions.template.md"
    output_filename: "businessplan-questions.md"
    scope: "phase"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`