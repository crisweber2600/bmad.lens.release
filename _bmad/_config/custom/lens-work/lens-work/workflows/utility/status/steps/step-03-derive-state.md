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

> **Batch optimization:** Pre-load all initiative configs in a single pass before iterating. This avoids N sequential `git-state.initiative-config` calls.

```yaml
status_rows = []
detail_rows = []
lifecycle = load("{lifecycleContract}")

# Batch-load all initiative configs upfront
initiative_configs = {}
for root in initiative_roots:
  initiative_configs[root] = invoke: git-state.initiative-config
  params:
    root: ${root}

default_audience_order = ["small", "medium", "large", "base"]

# Batch-collect all PR queries across all initiatives
# Build tuples of {head, base, root, type, phase} for a single batch call
pr_query_tuples = []

for root in initiative_roots:
  initiative_config = initiative_configs[root]
  if initiative_config == null:
    initiative_config = {}
  allowed_audiences = (initiative_config.track != null and lifecycle.tracks[initiative_config.track] != null and lifecycle.tracks[initiative_config.track].audiences != null) ? lifecycle.tracks[initiative_config.track].audiences : default_audience_order
  enabled_phases = (initiative_config.track != null and lifecycle.tracks[initiative_config.track] != null) ? lifecycle.tracks[initiative_config.track].phases : lifecycle.phase_order

  # Determine current audience
  audience_scan_order = reverse(allowed_audiences)
  current_audience = null
  for audience_name in audience_scan_order:
    audience_branch = "${root}-${audience_name}"
    if current_audience == null and branch_exists(audience_branch):
      current_audience = audience_name

  if current_audience != null:
    # Queue phase branch PR queries
    for phase_name in enabled_phases:
      phase_branch = "${root}-${current_audience}-${phase_name}"
      if branch_exists(phase_branch):
        pr_query_tuples.append({
          head: phase_branch,
          base: "${root}-${current_audience}",
          key: "${root}::phase::${phase_name}",
          root: root,
          type: "phase",
          phase: phase_name
        })

    # Queue promotion PR query
    current_audience_index = index_of(allowed_audiences, current_audience)
    next_audience = current_audience_index >= 0 and current_audience_index < allowed_audiences.length - 1 ? allowed_audiences[current_audience_index + 1] : null
    if next_audience != null:
      pr_query_tuples.append({
        head: "${root}-${current_audience}",
        base: "${root}-${next_audience}",
        key: "${root}::promotion",
        root: root,
        type: "promotion"
      })

# Execute batch PR status query (single API call instead of N sequential calls)
pr_results = invoke: git-orchestration.batch-query-pr-status
params:
  queries: ${pr_query_tuples}
# Returns: map of key -> {state, review_decision, pr_created_at}
# If batch-query-pr-status is unavailable, fall back to individual calls below

for root in initiative_roots:
  initiative_config = initiative_configs[root]

  if initiative_config == null:
    initiative_config = {}

  # v3.4: Check for feature.yaml-based state (2-branch topology)
  track_config = (initiative_config.track != null and lifecycle.tracks[initiative_config.track] != null) ? lifecycle.tracks[initiative_config.track] : {}
  use_feature_yaml = track_config.feature_yaml == true

  if use_feature_yaml:
    # Read feature.yaml from the feature branch for authoritative state
    raw_feature_yaml = invoke_command("git show origin/${root}:feature.yaml 2>/dev/null")
    if raw_feature_yaml != null and raw_feature_yaml != "":
      feature_state = parse_yaml(raw_feature_yaml)

      # For 2-branch topology, phase/milestone comes from feature.yaml
      current_audience = null   # 2-branch has no audience concept
      current_phase = feature_state.current_phase
      current_milestone_label = feature_state.current_milestone

      # Check for a single PR from featureId to main
      pr_state = invoke: git-orchestration.query-pr-status
      params:
        head: ${root}
        base: main
      pr_summary = pr_state.state == "open" ? "1 ⏳" : (pr_state.state == "merged" ? "1 ✅" : "0")

      # Derive action from feature.yaml status
      if feature_state.status == "complete" or feature_state.status == "archived":
        pending_action = "Completed"
      else if pr_state.state == "open":
        pending_action = pr_state.review_decision == "approved" ? "Awaiting merge" : "Awaiting review"
      else if current_phase != null:
        pending_action = "Continue /" + current_phase
      else:
        pending_action = "Ready for execution"

      status_row = {
        initiative: root,
        is_current: root == current_initiative_root,
        audience: "(2-branch)",
        phase: current_phase,
        prs: pr_summary,
        action: pending_action,
        completed_phases: [],
        track: initiative_config.track,
        blocked_reason: null,
        health_status: "healthy",
        stuck_reason: null,
        completeness_badge: feature_state.current_milestone || "—",
        stories_badge: null
      }

      status_rows.append(status_row)
      if detail_initiative == root or initiative_roots.length == 1:
        detail_rows.append(status_row)

      continue   # Skip legacy state derivation for this initiative

  # --- LEGACY STATE DERIVATION (unchanged) ---
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
        # Use batched result instead of individual PR query
        pr_state = pr_results["${root}::phase::${phase_name}"] || { state: "unknown", review_decision: null }

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
        # Use batched result for promotion PR
        promotion_pr_state = pr_results["${root}::promotion"] || { state: "unknown" }

        if promotion_pr_state.state == "open":
          pending_action = "Promotion in review"
          pr_summary = "1 ⏳"
        else if promotion_pr_state.state == "merged":
          pending_action = "Start next audience"
          pr_summary = "1 ✅"

  # Health indicator: stuck detection
  health_status = "healthy"
  stuck_reason = null
  if current_phase != null and active_phase != null and active_phase.state == "open":
    pr_age_days = days_since(active_phase.pr_created_at || now())
    if pr_age_days > 14:
      health_status = "stuck"
      stuck_reason = "PR open ${pr_age_days} days"
    else if pr_age_days > 7:
      health_status = "warning"
      stuck_reason = "PR open ${pr_age_days} days"

  # Completeness tracking
  completeness_total = audience_phases.length > 0 ? audience_phases.length : 1
  completeness_done = completed_phases.length
  completeness_badge = "${completeness_done}/${completeness_total}"

  # Story-state tracking
  story_state = initiative_config.story_state || null
  stories_total = story_state != null ? (story_state.total || 0) : 0
  stories_done = story_state != null ? (story_state.completed || 0) : 0
  stories_badge = stories_total > 0 ? "${stories_done}/${stories_total}" : null

  status_row = {
    initiative: root,
    is_current: root == current_initiative_root,
    audience: current_audience,
    phase: current_phase,
    prs: pr_summary,
    action: pending_action,
    completed_phases: completed_phases,
    track: initiative_config.track,
    blocked_reason: null,
    health_status: health_status,
    stuck_reason: stuck_reason,
    completeness_badge: completeness_badge,
    stories_badge: stories_badge
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

### 2. Load Portfolio Data From Feature Index *(v3.3)*

When `features_registry.enabled`, load cross-feature data from `feature-index.yaml` on main
and enrich status rows with relationship and staleness information. This pre-loads data
for step-04 rendering and avoids duplicate git queries.

```yaml
features_registry_config = load("{lifecycleContract}").features_registry
if features_registry_config.enabled:

  # 2a. Read feature-index.yaml from main without switching branches
  raw_index = invoke_command("git show origin/main:${features_registry_config.file} 2>/dev/null")

  if raw_index != null and raw_index != "":
    feature_index = parse_yaml(raw_index)

    # 2b. Build relationship lookup: feature → {depends_on, blocks, related}
    relationship_map = {}
    for entry in feature_index.features:
      relationship_map[entry.key] = entry.relationships || { depends_on: [], blocks: [], related: [] }

    # 2c. Check staleness per initiative from initiative-state.yaml on each feature branch
    staleness_map = {}
    for root in initiative_roots:
      raw_state = invoke_command("git show origin/${root}:initiative-state.yaml 2>/dev/null")
      if raw_state != null and raw_state != "":
        state = parse_yaml(raw_state)
        if state.context and state.context.stale == true:
          staleness_map[root] = {
            stale: true,
            last_pulled: state.context.last_pulled || null
          }

    # 2d. Enrich status_rows with cross-feature data
    for row in status_rows:
      rels = relationship_map[row.initiative] || null
      if rels != null:
        row.depends_on = rels.depends_on || []
        row.blocks = rels.blocks || []
        row.related = rels.related || []
      row.context_stale = staleness_map[row.initiative] != null

    # 2e. Store for step-04 rendering
    portfolio_data = {
      feature_index: feature_index,
      relationship_map: relationship_map,
      staleness_map: staleness_map
    }

    output: |
      📦 Portfolio data loaded
      ├── Features indexed: ${feature_index.features.length}
      ├── Stale contexts: ${Object.keys(staleness_map).length}
      └── Relationships mapped: ${Object.keys(relationship_map).length}

  else:
    portfolio_data = null
    output: "ℹ️  Feature index not found on main — portfolio view unavailable"

else:
  portfolio_data = null
```

### 3. Pending Action Rules

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