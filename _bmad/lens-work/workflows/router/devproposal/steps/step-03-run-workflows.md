---
name: 'step-03-run-workflows'
description: 'Invoke epics, stories, readiness, and the optional epic stress gates'
nextStepFile: './step-04-closeout.md'
---

# Step 3: Run The DevProposal Workflows

**Goal:** Generate epics and stories, optionally run the epic stress gates, and complete the readiness pass.

---

## EXECUTION SEQUENCE

### 1. Generate Epics And Stories

```yaml
read_and_follow: "lens.core/_bmad/bmm/workflows/3-solutioning/bmad-create-epics-and-stories/workflow.md"
params:
  architecture: "${docs_path}/architecture.md"
  prd: "${docs_path}/prd.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}

read_and_follow: "lens.core/_bmad/bmm/workflows/3-solutioning/bmad-create-epics-and-stories/workflow.md"
params:
  mode: "stories"
  epics: "${docs_path}/epics.md"
  architecture: "${docs_path}/architecture.md"
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}
```

### 2. Run Optional Epic Stress Gates And Readiness

```yaml
if run_epic_stress_gate:
  read_and_follow: "lens.core/_bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md"
  params:
    mode: "adversarial"
    scope: "epic"
    epics: "${docs_path}/epics.md"
    prd: "${docs_path}/prd.md"
    architecture: "${docs_path}/architecture.md"
    constitutional_context: ${constitutional_context}

  read_and_follow: "lens.core/_bmad/core/skills/bmad-party-mode/workflow.md"
  params:
    input_file: "${docs_path}/epics.md"
    artifacts_path: "${docs_path}/"

read_and_follow: "lens.core/_bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md"
params:
  artifacts:
    - product-brief.md
    - prd.md
    - architecture.md
    - epics.md
    - stories.md
  output_path: "${docs_path}/"
  constitutional_context: ${constitutional_context}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`