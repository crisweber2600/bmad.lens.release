---
name: 'step-03-derive-state'
description: 'Derive audience, phase, PR state, and next action per initiative'
nextStepFile: './step-04-render-report.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 3: Derive Initiative State

**Goal:** Build the current status row for each initiative using git-derived audience, phase, PR state, and pending action data.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Use `lifecycle.yaml`, branch existence, and PR metadata as the only status sources.
- Guard against malformed or unknown track values by falling back to lifecycle phase order.

### 1. Build Status Rows

```yaml
status_rows = []
detail_rows = []
lifecycle = load("{lifecycleContract}")

default_audience_order = ["small", "medium", "large", "base"]

for root in initiative_roots:
  initiative_config = invoke: git-state.initiative-config
  params:
    root: ${root}

  if initiative_config == null:
    initiative_config = {}

  current_audience = null
  current_phase = null
  pr_summary = "0"
  pending_action = "Review branch state"
  completed_phases = []
  phase_status_rows = []
  allowed_audiences = (initiative_config.track != null and lifecycle.tracks[initiative_config.track] != null and lifecycle.tracks[initiative_config.track].audiences != null) ? lifecycle.tracks[initiative_config.track].audiences : default_audience_order
  audience_scan_order = reverse(allowed_audiences)
  enabled_phases = (initiative_config.track != null and lifecycle.tracks[initiative_config.track] != null) ? lifecycle.tracks[initiative_config.track].phases : lifecycle.phase_order

  for audience_name in audience_scan_order:
    audience_branch = "${root}-${audience_name}"
    if current_audience == null and branch_exists(audience_branch):
      current_audience = audience_name

  if current_audience != null:
    current_audience_phases = lifecycle.audiences[current_audience] != null ? lifecycle.audiences[current_audience].phases : []
    audience_phases = filter(current_audience_phases, phase_name -> contains(enabled_phases, phase_name))

    for phase_name in enabled_phases:
      phase_branch = "${root}-${current_audience}-${phase_name}"
      if branch_exists(phase_branch):
        pr_state = invoke: git-orchestration.query-pr-status
        params:
          head: ${phase_branch}
          base: "${root}-${current_audience}"

        phase_status_rows.append({
          phase: phase_name,
          branch: phase_branch,
          state: pr_state.state,
          review_decision: pr_state.review_decision
        })

        if pr_state.state == "merged":
          completed_phases.append(phase_name)

    active_phase = last(phase_status_rows where item.state != "merged")

    if active_phase != null:
      current_phase = active_phase.phase

      if active_phase.state == "open":
        pr_summary = "1 ⏳"
        if active_phase.review_decision == "approved":
          pending_action = "Awaiting merge"
        else if active_phase.review_decision == "changes_requested":
          pending_action = "Address review feedback"
        else:
          pending_action = "Awaiting review"
      else:
        pending_action = "Complete phase"

    if current_phase == null and current_audience != null:
      remaining_phases = filter(audience_phases, phase_name -> not contains(completed_phases, phase_name))
      current_phase = remaining_phases.length > 0 ? remaining_phases[0] : null
      pending_action = current_audience == "base" ? "Ready for execution" : (current_phase != null ? "Start next phase" : "Review branch state")

    if audience_phases.length > 0 and completed_phases.length == audience_phases.length:
      pending_action = "Ready to promote"
      pr_summary = completed_phases.length > 0 ? "${completed_phases.length} ✅" : pr_summary

      current_audience_index = index_of(allowed_audiences, current_audience)
      next_audience = current_audience_index >= 0 and current_audience_index < allowed_audiences.length - 1 ? allowed_audiences[current_audience_index + 1] : null

      if next_audience != null:
        promotion_pr_state = invoke: git-orchestration.query-pr-status
        params:
          head: "${root}-${current_audience}"
          base: "${root}-${next_audience}"

        if promotion_pr_state.state == "open":
          pending_action = "Promotion in review"
          pr_summary = "1 ⏳"
        else if promotion_pr_state.state == "merged":
          pending_action = "Start next audience"
          pr_summary = "1 ✅"

  status_row = {
    initiative: root,
    is_current: root == current_initiative_root,
    audience: current_audience,
    phase: current_phase,
    prs: pr_summary,
    action: pending_action,
    completed_phases: completed_phases,
    track: initiative_config.track,
    blocked_reason: null
  }

  status_rows.append(status_row)

  if detail_initiative == root or initiative_roots.length == 1:
    detail_rows.append(status_row)

if detail_rows.length == 0 and detail_initiative != "":
  warning: "Requested detailed initiative not found: ${detail_initiative}"

output: |
  ✅ Status derivation complete
  ├── Rows built: ${status_rows.length}
  └── Detailed rows: ${detail_rows.length}
```

### 2. Pending Action Rules

Apply the lifecycle rules consistently using `lifecycle.yaml`, branch existence, and PR state:

1. Phase branch exists and no PR is open -> `Complete phase`
2. PR is open and not approved -> `Awaiting review`
3. PR merged and next phase is available -> `Start next phase`
4. All phases for the audience are complete -> `Ready to promote`

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`

## SUCCESS CRITERIA

- Each initiative produces one summary row with audience, phase, PR summary, and next action.
- Promotion PR state is considered whenever the current audience is ready to advance.