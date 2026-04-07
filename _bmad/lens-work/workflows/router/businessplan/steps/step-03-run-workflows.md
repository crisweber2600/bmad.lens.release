---
name: 'step-03-run-workflows'
description: 'Invoke the selected PRD, UX, and architecture workflows'
nextStepFile: './step-04-closeout.md'
---

# Step 3: Run The Selected Workflows

**Goal:** Execute the selected businessplan sub-workflows in the correct order while preserving the PM and UX interaction model.

---

## EXECUTION SEQUENCE

### 1. Run PRD And UX Work

```yaml
read_and_follow: "lens.core/_bmad/core/tasks/bmad-create-prd/workflow.md"
params:
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

read_and_follow: "lens.core/_bmad/bmm/workflows/2-plan-workflows/bmad-validate-prd/workflow.md"
params:
  prd_path: "${docs_path}/prd.md"

if contains(selected_workflows, "ux"):
  read_and_follow: "lens.core/_bmad/bmm/workflows/2-plan-workflows/bmad-create-ux-design/workflow.md"
  params:
    prd: "${docs_path}/prd.md"
    product_brief: "${docs_path}/product-brief.md"
    output_path: "${docs_path}/"
    constitutional_context: ${constitutional_context}
```

### 2. Run Architecture Work

```yaml
read_and_follow: "lens.core/_bmad/bmm/workflows/3-solutioning/bmad-create-architecture/workflow.md"
params:
  prd: "${docs_path}/prd.md"
  product_brief: "${docs_path}/product-brief.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`