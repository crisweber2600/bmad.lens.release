---
name: 'step-01-preflight'
description: 'Run shared preflight, validate techplan eligibility, and mark phase start on initiative root branch'
nextStepFile: './step-02-select-mode.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And Phase Start

**Goal:** Confirm the active initiative can run techplan, verify inherited planning artifacts, and mark phase start on the initiative root branch.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Resolve Initiative Context

```yaml
invoke: include
path: "{preflightInclude}"
params:
  skip_constitution: true

invoke: git-orchestration.verify-clean-state

initiative_state = invoke: git-state.current-initiative
initiative = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

initiative_root = initiative.initiative_root
docs_path = initiative.docs.path || "{output_folder}/planning-artifacts"

ensure_directory(docs_path)

prd = load_if_exists("${docs_path}/prd.md")
if prd == null:
  FAIL("❌ TechPlan requires prd.md under ${docs_path}.")

# v3: Check businessplan completion via initiative-state.yaml (not branch PR merge)
state = load(initiative_state.state_path)
if state.artifacts.businessplan == null:
  warning: "⚠️ BusinessPlan artifacts not recorded in initiative-state.yaml. TechPlan can continue, but inherited artifacts may be incomplete."

constitutional_context = invoke: constitution.resolve-context
session.constitutional_context = constitutional_context

# v3: Work directly on the initiative root branch — no phase branch creation
current_branch = invoke_command("git symbolic-ref --short HEAD")
if current_branch != initiative_root:
  invoke: git-orchestration.checkout-branch
  params:
    branch: ${initiative_root}

invoke: git-orchestration.pull-latest

# Mark phase start in initiative-state.yaml and commit the marker
invoke: git-orchestration.update-phase-start
params:
  phase: techplan

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${initiative_state.state_path}
  phase: "PHASE:TECHPLAN:START"
  initiative: ${initiative_root}
  description: "techplan phase started"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`