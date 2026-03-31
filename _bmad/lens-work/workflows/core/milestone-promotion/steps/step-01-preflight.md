---
name: 'step-01-preflight'
description: 'Run preflight, resolve the active initiative, and determine the current and next milestones'
nextStepFile: './step-02-run-gates.md'
preflightInclude: '../../includes/preflight.md'
lifecycleContract: '../../../lifecycle.yaml'
---

# Step 1: Preflight And Milestone Resolution

**Goal:** Confirm the current branch belongs to an initiative, resolve the current milestone, and determine whether a next milestone exists.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Resolve Promotion Context

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
initiative_config = load(initiative_state.config_path)
lifecycle = load("{lifecycleContract}")

milestone_state = invoke: git-state.current-milestone
current_milestone = milestone_state.milestone || ""

track_name = initiative_config.track || "full"
track_config = lifecycle.tracks[track_name] || {}
milestone_chain = track_config.milestones || ["techplan", "devproposal", "sprintplan", "dev-ready"]
milestone_index = index_of(milestone_chain, current_milestone)

if milestone_index < 0:
  FAIL("❌ Current milestone `${current_milestone}` is not valid for track `${track_name}`.")

next_milestone = milestone_index < milestone_chain.length - 1 ? milestone_chain[milestone_index + 1] : ""

if next_milestone == "":
  output: "✅ Initiative is already at the final milestone. No promotion is available."
  exit: 0

initiative_root = initiative_config.initiative_root
source_branch = "${initiative_root}-${current_milestone}"
target_branch = "${initiative_root}-${next_milestone}"
gate_failures = []
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`