---
name: 'step-02-select-workflows'
description: 'Capture the preplan workflow selection and execution mode'
nextStepFile: './step-03-run-workflows.md'
---

# Step 2: Select PrePlan Workflows

**Goal:** Decide which preplan components to run and whether the user wants interactive or batch execution where supported.

---

## EXECUTION SEQUENCE

### 1. Capture Selection And Mode

```yaml
output: |
  🧭 /preplan

  Available workflows:
  - Brainstorming (optional)
  - Research (optional)
  - Product Brief (required)

  Recommended path: brainstorming → research → product brief

ask: "Which workflows should run? Use brainstorming, research, all, or product-brief-only."
capture: workflow_selection

ask: "Execution mode? [interactive/batch]"
capture: execution_mode

selected_workflows = workflow_selection == "all" ? ["brainstorming", "research", "product-brief"] : contains(workflow_selection, "research") ? ["research", "product-brief"] : contains(workflow_selection, "brainstorming") ? ["brainstorming", "product-brief"] : ["product-brief"]

if contains(selected_workflows, "research"):
  ask: "Which research type should run? [market/domain/technical]"
  capture: research_type

if execution_mode == "batch" and contains(selected_workflows, "brainstorming"):
  warning: "⚠️ Brainstorming remains interactive. Batch mode will apply only after brainstorming completes."
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`