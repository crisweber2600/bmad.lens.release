# PR Include: Sensing Report

**Usage:** Included in promotion PR bodies by the audience-promotion workflow.
**Updated:** v3.1 — added content-aware sensing section.

---

## Cross-Initiative Sensing

### Template: Overlaps Found (Scope-Based)

```markdown
## Cross-Initiative Sensing

⚠️ Active initiatives in domain `{domain}`:

| Initiative | Phase | Audience | Conflict Level | Reason |
|------------|-------|----------|---------------|--------|
| `{init-1}` | {phase} | {audience} | 🔴 High | Same service — scope overlap |
| `{init-2}` | {phase} | {audience} | 🟡 Medium | Same domain |

{if constitution hard gate}
### ⚠️ REQUIRES EXPLICIT CONFLICT REVIEW
Constitution requires explicit conflict resolution for domain `{domain}`.
Reviewer must confirm no destructive overlap before merging.
{end if}

{if informational (default)}
### Informational
Review overlapping initiatives for potential coordination needs.
{end if}
```

### Template: Content-Aware Overlaps (v3.1)

When `lifecycle.yaml` → `sensing.content_overlap.enabled` is true:

```markdown
## Content-Aware Overlap Analysis

📄 Artifact content comparison across overlapping initiatives:

| Initiative A | Initiative B | Artifact | Similarity | Overlapping Sections |
|-------------|-------------|----------|-----------|---------------------|
| `{init-1}` | `{init-2}` | epics | 🔴 82% | "Payment Processing", "Auth Flow" |
| `{init-1}` | `{init-3}` | stories | 🟡 45% | "Create endpoint" |

{if similarity > threshold (default 0.7)}
### ⚠️ HIGH CONTENT OVERLAP DETECTED
Initiatives `{init-1}` and `{init-2}` share significant artifact content.
This likely indicates duplicated scope or conflicting implementations.

**Recommended action:** Coordinate with initiative owners before proceeding.
{end if}

{if similarity <= threshold}
### Informational — Low Content Overlap
Content similarity is below the threshold ({threshold}).
Scope overlap is nominal and likely intentional.
{end if}
```

### Template: No Overlaps

```markdown
## Cross-Initiative Sensing

No overlapping initiatives detected ✅

Scanned {count} active initiative(s) across all domains.
{if content_overlap_enabled}Content-aware analysis: no significant artifact overlap found.{end if}
```

### Template: Relationship Conflicts *(v3.3)*

When `features_registry.enabled` and `sensing.scan-relationship-conflicts` (Pass 3)
is active, append a relationship conflict section. This surfaces dependency ordering
violations, circular dependencies, and blocked feature issues.

```markdown
## Relationship Conflicts (Cross-Feature Visibility)

{if relationship_violations.length > 0}
⚠️ Relationship conflicts detected across ${scanned_features} features:

### Dependency Ordering Violations

Features that have progressed ahead of their declared dependencies:

| Feature | Depends On | Feature Status | Dependency Status | Severity |
|---------|-----------|----------------|-------------------|----------|
| `{feature}` | `{dependency}` | {feature_status} | {dep_status} | 🔴 High |

{end if}

{if circular_deps.length > 0}
### Circular Dependencies

Dependency cycles that may cause coordination deadlocks:

${for cycle in circular_deps:}
- 🔄 ${cycle.join(" → ")} → ${cycle[0]}
${endfor}

**Recommended action:** Break the cycle by removing one dependency or merging the features.
{end if}

{if blocked_features.length > 0}
### Blocked Features

Features that cannot progress because their dependencies are incomplete:

| Blocked Feature | Blocked By | Dependency Status | Action |
|----------------|-----------|-------------------|--------|
| `{blocked}` | `{blocker}` | {blocker_status} | Prioritize {blocker} |

{end if}

{if relationship_violations.length == 0 and circular_deps.length == 0 and blocked_features.length == 0}
### Relationship Conflicts

No relationship conflicts detected ✅

Scanned ${scanned_features} feature(s) with ${total_relationships} declared relationships.
{end if}
```

## Integration Notes

- This section is ALWAYS present in promotion PRs, even when no overlaps are found
- The sensing skill produces the data; this include defines the PR body format
- Constitution can upgrade sensing from informational to hard gate per domain/service
- When hard gate: add explicit review requirement banner
- When informational: show as advisory section
- Content-aware sensing compares by section headers (diff_strategy: section-headers)
- Similarity threshold is configurable in lifecycle.yaml (default: 0.7)
- Relationship conflict section (v3.3) only renders when `features_registry.enabled`
- Relationship data sourced from `feature-index.yaml` on main via `sensing.scan-relationship-conflicts` (Pass 3)
- Pass 3 violation counts are included in the Summary section when present
