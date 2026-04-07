---
name: 'step-04-render-report'
description: 'Render the compact summary table and optional detailed initiative view'
---

# Step 4: Render Status Output

**Goal:** Present the initiative status report in a compact table first, then expand into detail when the interaction warrants it.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Render the report directly from `status_rows` and `detail_rows`.
- Keep the default output within the five-column summary-table constraint.

### 1. Render The Summary Table

```yaml
health_icon = lambda row: row.health_status == "stuck" ? "❌" : (row.health_status == "warning" ? "🟡" : "✅")

summary_rows = map(status_rows, row -> "| " + (row.is_current ? "► " : "") + row.initiative + " | " + (row.phase || "-") + " | " + (row.audience || "-") + " | " + row.prs + " | " + health_icon(row) + " " + row.action + " |")

output: |
  📊 Initiative Status Report

  | Initiative | Phase | Audience | PRs | Action |
  |------------|-------|----------|-----|--------|
  ${summary_rows.join("\n")}

  Status indicators:
  - ✅ healthy / phase complete
  - 🟡 warning (PR open > 7 days)
  - ❌ stuck (PR open > 14 days)
  - ⏳ PR open or awaiting review
  - ▶ current initiative row
```

### 2. Render Detailed View When Needed

```yaml
if detail_rows.length > 0:
  for row in detail_rows:
    stuck_line = row.stuck_reason != null ? "\n  ⚠️ " + row.stuck_reason : ""
    stories_line = row.stories_badge != null ? "\n  📖 Stories: " + row.stories_badge : ""

    output: |
      📂 Initiative: ${row.initiative}
      🏷️ Track: ${row.track != null ? row.track : "(not set)"}
      👥 Audience: ${row.audience}
      📋 Phases complete: ${row.completeness_badge}${stories_line}${stuck_line}
      📋 Completed Phases: ${row.completed_phases.join(", ")}
      ⏳ Current Phase: ${row.phase}
      📝 Open PRs: ${row.prs}
      🔄 Pending: ${row.action}
```

### 3. Render Portfolio View From Feature Index *(v3.3)*

When `features_registry.enabled`, render additional portfolio sections sourced entirely
from `feature-index.yaml` on main. No branch switching required.

```yaml
features_registry_config = load("lifecycle.yaml").features_registry
if features_registry_config.enabled:
  feature_index = git show origin/main:${features_registry_config.file} 2>/dev/null
  if feature_index is not null:
    index = parse_yaml(feature_index)

    # 3a. Portfolio Overview — all features by domain
    domain_groups = group_by(index.features, f -> f.domain)
    output: |

      📦 Portfolio Overview (from feature-index.yaml on main)

      ${for domain, features in domain_groups:}
      **${domain}:**
      | Feature | Service | Status | Owner | Updated | Summary |
      |---------|---------|--------|-------|---------|---------|
      ${for f in features:}
      | ${f.key} | ${f.service} | ${f.status} | ${f.owner || '-'} | ${f.updated_at || '-'} | ${f.summary || '-'} |
      ${endfor}
      ${endfor}

    # 3b. Staleness Alerts — features where context is known stale
    stale_features = []
    for feature_name, feature in index.features:
      # Read initiative-state.yaml context.stale if accessible
      state = git show origin/${feature_name}:initiative-state.yaml 2>/dev/null
      if state and state.context and state.context.stale == true:
        stale_features.append(feature_name)

    if stale_features.length > 0:
      output: |

        ⚠️ Stale Context Alerts
        The following features have not refreshed cross-feature context since related features updated:
        ${for f in stale_features: echo "  - ${f}"}
        Run `/refresh-context` on these features to update.

    # 3c. Dependency Summary — blocking relationships
    blocking_pairs = []
    for feature_name, feature in index.features:
      if feature.relationships and feature.relationships.blocks:
        for blocked in feature.relationships.blocks:
          blocking_pairs.append("${feature_name} blocks ${blocked}")
      if feature.relationships and feature.relationships.depends_on:
        for dep in feature.relationships.depends_on:
          blocking_pairs.append("${feature_name} depends on ${dep}")

    if blocking_pairs.length > 0:
      output: |

        🔗 Dependency Chains
        ${for pair in blocking_pairs: echo "  - ${pair}"}
```

### 4. Close With The Execution Hint

```yaml
output: "Use `/next` for the active initiative when you want the recommended next command."
```

## SUCCESS CRITERIA

- The summary table contains one rendered row per initiative.
- Detailed output appears only when requested or when a single initiative exists.