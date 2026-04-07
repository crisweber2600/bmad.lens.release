---
name: 'step-03-run-workflows'
description: 'Invoke the selected brainstorming, research, and product-brief workflows'
nextStepFile: './step-04-closeout.md'
---

# Step 3: Run The Selected Workflows

**Goal:** Execute the chosen preplan sub-workflows in the correct order while preserving the required analyst-led interaction model.

---

## EXECUTION SEQUENCE

### 1. Run Brainstorming And Research When Selected

```yaml
if contains(selected_workflows, "brainstorming"):
  read_and_follow: "lens.core/_bmad/core/skills/bmad-brainstorming/workflow.md"
  params:
    context: "${initiative.initiative_root} preplan"

if contains(selected_workflows, "research"):
  research_workflow = research_type == "market" ? "lens.core/_bmad/bmm/workflows/1-analysis/research/bmad-market-research/workflow.md" : research_type == "domain" ? "lens.core/_bmad/bmm/workflows/1-analysis/research/bmad-domain-research/workflow.md" : "lens.core/_bmad/bmm/workflows/1-analysis/research/bmad-technical-research/workflow.md"
  read_and_follow: ${research_workflow}
```

### 2. Always Run Product Brief

```yaml
read_and_follow: "lens.core/_bmad/bmm/workflows/1-analysis/bmad-create-product-brief/workflow.md"
params:
  output_path: "${output_path}/"
  context:
    brainstorm_notes: "${output_path}/brainstorm-notes.md"
    research_summary: "${output_path}/research-summary.md"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`