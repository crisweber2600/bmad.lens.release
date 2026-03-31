---
name: 'step-01-preflight'
description: 'Run shared preflight, validate businessplan eligibility, and mark phase start on initiative root branch'
nextStepFile: './step-02-select-workflows.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And Phase Start

**Goal:** Confirm the active initiative can run businessplan, verify the inherited product brief, and mark phase start on the initiative root branch.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Resolve Initiative Context

```yaml
invoke: include
path: "{preflightInclude}"

invoke: git-orchestration.verify-clean-state

initiative_state = invoke: git-state.current-initiative
initiative = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

initiative_root = initiative.initiative_root
docs_path = initiative.docs.path || "{output_folder}/planning-artifacts"

ensure_directory(docs_path)

product_brief = load_if_exists("${docs_path}/product-brief.md")
if product_brief == null:
  FAIL("❌ Product brief not found at ${docs_path}/product-brief.md.")

# v3: Check preplan completion via initiative-state.yaml (not branch PR merge)
state = load(initiative_state.state_path)
if state.artifacts.preplan == null:
  warning: "⚠️ Preplan artifacts not recorded in initiative-state.yaml. BusinessPlan can continue, but inherited artifacts may be incomplete."

# v3: Work directly on the initiative root branch — no phase branch creation
current_branch = invoke_command("git symbolic-ref --short HEAD")
if current_branch != initiative_root:
  invoke: git-orchestration.checkout-branch
  params:
    branch: ${initiative_root}

invoke: git-orchestration.pull-latest

invoke: lens-work.compliance-check
params:
  phase: "businessplan"
  artifacts_path: ${docs_path}

constitutional_context = invoke: constitution.resolve-context
session.constitutional_context = constitutional_context

# Mark phase start in initiative-state.yaml and commit the marker
invoke: git-orchestration.update-phase-start
params:
  phase: businessplan

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${initiative_state.state_path}
  phase: "PHASE:BUSINESSPLAN:START"
  initiative: ${initiative_root}
  description: "businessplan phase started"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`