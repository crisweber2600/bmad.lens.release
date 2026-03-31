---
name: 'step-03-run-workflows'
description: 'Invoke architecture, technical decisions, optional API contracts, and readiness validation'
nextStepFile: './step-04-closeout.md'
---

# Step 3: Run The TechPlan Workflows

**Goal:** Generate the technical architecture outputs and validate they are implementation-ready.

---

## EXECUTION SEQUENCE

### 1. Run Architecture And Technical Design

```yaml
read_and_follow: "_bmad/bmm/workflows/3-solutioning/bmad-create-architecture/workflow.md"
params:
  context:
    product_brief: "${docs_path}/product-brief.md"
    prd: "${docs_path}/prd.md"
    epics: "${docs_path}/epics.md"
  output_file: "${docs_path}/architecture.md"

invoke: workflow-step
params:
  step: tech-decisions
  context:
    product_brief: "${docs_path}/product-brief.md"
    prd: "${docs_path}/prd.md"
  output_file: "${docs_path}/tech-decisions.md"

if include_api_contracts:
  invoke: workflow-step
  params:
    step: api-contracts
    context:
      architecture: "${docs_path}/architecture.md"
    output_file: "${docs_path}/api-contracts.md"
```

### 2. Run Readiness Validation

```yaml
read_and_follow: "_bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md"
params:
  architecture: "${docs_path}/architecture.md"
  prd: "${docs_path}/prd.md"
  tech_decisions: "${docs_path}/tech-decisions.md"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`