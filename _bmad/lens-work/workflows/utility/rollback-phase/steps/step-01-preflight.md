---
name: 'step-01-preflight'
description: 'Run shared preflight and validate rollback eligibility'
nextStepFile: './step-02-confirm-rollback.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Validation

**Goal:** Verify the control repo is ready, determine current phase, and validate rollback is possible.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
current_initiative_root = initiative_state.initiative_root
```

### 2. Validate Initiative Context

```yaml
if current_initiative_root == null:
  output: "⛔ Not on an initiative branch. Switch to an initiative first with `/switch`."
  STOP

state_file = "{current_initiative_root}/initiative-state.yaml"
if not exists(state_file):
  output: "⛔ No initiative-state.yaml found. This initiative may not be initialized."
  STOP

current_phase = read_yaml(state_file, "phase")
current_milestone = read_yaml(state_file, "milestone")
```

### 3. Load Phase Ordering

```yaml
lifecycle = load: "{release_repo_root}/lens.core/_bmad/lens-work/lifecycle.yaml"
phase_order = lifecycle.phases | keys  # ordered list of phase names

current_index = phase_order.index(current_phase)
if current_index <= 0:
  output: "⛔ Already at the first phase (${current_phase}). Nothing to roll back to."
  STOP
```

### 4. Check For Blocking PRs

```yaml
pr_info = invoke: git-orchestration.query-pr-status
  head: "{current_initiative_root}-{current_milestone}"

if pr_info != null and pr_info.state == "open":
  output: |
    ⛔ **Open PR blocks rollback.**
    PR #${pr_info.number} is open for the current milestone.
    Close or merge it before rolling back.
  STOP
```

---

## OUTPUT CONTRACT

```yaml
output:
  current_initiative_root: string
  current_phase: string
  current_milestone: string
  phase_order: string[]
  available_targets: string[]  # phases before current
```

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
