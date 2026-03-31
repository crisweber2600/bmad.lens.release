---
name: 'step-01-preflight'
description: 'Run shared preflight, validate techplan prerequisite via initiative-state.yaml, and confirm branch context'
nextStepFile: './step-02-select-mode.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Preflight And TechPlan Prerequisite Validation

**Goal:** Confirm the active initiative can run devproposal, verify techplan phase is complete via `initiative-state.yaml`, and confirm the current branch context.

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
current_branch = invoke_command("git symbolic-ref --short HEAD")
docs_path = initiative.docs.path || "{output_folder}/planning-artifacts"

ensure_directory(docs_path)

prd = load_if_exists("${docs_path}/prd.md")
architecture = load_if_exists("${docs_path}/architecture.md")
if prd == null or architecture == null:
  FAIL("❌ DevProposal requires prd.md and architecture.md under ${docs_path}.")

# --- Prerequisite: techplan must be complete ---
state_yaml = load("initiative-state.yaml")
if state_yaml.phase_status.techplan != "complete":
  FAIL("❌ TechPlan phase is not complete. Run `/techplan` first.")

invoke: lens-work.compliance-check
params:
  phase: "devproposal"
  artifacts_path: ${docs_path}

constitutional_context = invoke: constitution.resolve-context
session.constitutional_context = constitutional_context

# --- Phase start marker ---
invoke: git-orchestration.update-phase-start
params:
  initiative_id: ${initiative.id || initiative_root}
  phase: "devproposal"
  branch: ${current_branch}
  commit_message: "[PHASE:DEVPROPOSAL:START] Begin devproposal on ${current_branch}"

invoke: git-orchestration.pull-latest
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`