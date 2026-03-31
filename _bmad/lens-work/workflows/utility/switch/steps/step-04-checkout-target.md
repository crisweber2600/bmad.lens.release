---
name: 'step-04-checkout-target'
description: 'Resolve the best branch for the target initiative and check it out'
nextStepFile: './step-05-report-context.md'
---

# Step 4: Resolve And Checkout The Target Branch

**Goal:** Check out the most actionable branch for the selected initiative using the documented branch-priority rules.

---

## EXECUTION SEQUENCE

### 1. Refresh And Resolve The Target Branch

```yaml
invoke_command("git fetch origin --prune")

target_branch = null
candidate_branches = []

for audience in ["base", "large", "medium", "small"]:
  audience_branch = "${target_root}-${audience}"
  if branch_exists(audience_branch):
    candidate_branches.append(audience_branch)

for phase_name in ["sprintplan", "devproposal", "techplan", "businessplan", "preplan"]:
  for audience in ["base", "large", "medium", "small"]:
    phase_branch = "${target_root}-${audience}-${phase_name}"
    if branch_exists(phase_branch):
      pr_state = invoke: git-orchestration.query-pr-status
      params:
        head: ${phase_branch}
        base: "${target_root}-${audience}"
      if pr_state.state == "open":
        candidate_branches.prepend(phase_branch)

target_branch = first(candidate_branches) || "${target_root}-small"

if branch_exists(target_branch):
  invoke: git-orchestration.checkout-branch
  params:
    branch: ${target_branch}
else if remote_branch_exists(target_branch):
  invoke_command("git checkout -b ${target_branch} origin/${target_branch}")
else:
  FAIL("❌ Initiative branch `${target_branch}` was not found locally or on origin.")
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`