# Skill: constitution

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Resolve the effective constitution for an initiative by merging the 4-level governance hierarchy. Provides deterministic constitutional resolution and compliance checking at lifecycle gates.

**Design Axiom A3:** Authority domains must be explicit. Every file belongs to exactly one authority.

## Write Operations

**NONE.** This skill is strictly read-only. It reads from the governance repo (Domain 4) and NEVER writes to it. Constitutional changes happen via PRs in the governance repo, not through this skill.

## Constitution Hierarchy

The governance repo contains constitutions at 4 levels, resolved bottom-up with additive inheritance:

```
lens-governance/constitutions/
├── org/
│   └── constitution.md              ← Level 1: org-wide defaults
├── {domain}/
│   └── constitution.md              ← Level 2: domain-specific rules
│   └── {service}/
│       └── constitution.md          ← Level 3: service-specific rules
│       └── {repo}/
│           └── constitution.md      ← Level 4: repo-specific rules
```

### Language-Specific Constitutions (POST-MVP — FR16)

When the initiative's language is known, an additional overlay may exist:

```
lens-governance/constitutions/{level}/{language}/constitution.md
```

The interface supports this, but the implementation is minimal for MVP.

## Resolution Algorithm

### `resolve-constitution`

Resolve the effective constitution for an initiative.

**Input:**
```yaml
domain: payments
service: auth
repo: auth-api         # optional — Level 4
language: typescript    # optional — language overlay
```

**Algorithm:**

1. Load Level 1: `constitutions/org/constitution.md`
2. Load Level 2: `constitutions/{domain}/constitution.md`
3. Load Level 3: `constitutions/{domain}/{service}/constitution.md`
4. Load Level 4: `constitutions/{domain}/{service}/{repo}/constitution.md` (if exists)
5. Merge using **additive inheritance**: lower levels ADD requirements, never remove
6. If language is specified and language constitution exists, merge language overlay

**Merge rules:**
- Union all `required_artifacts` lists
- Union all `required_gates` lists
- Lower level `gate_mode` overrides upper level (hard overrides informational)
- `permitted_tracks` is intersection (lower levels can only restrict)
- `additional_review_participants` is union

**Output:**
```yaml
resolved_constitution:
  domain: payments
  service: auth
  levels_loaded: [org, domain, service]
  permitted_tracks: [full, feature, tech-change, hotfix]
  required_artifacts:
    preplan: [product-brief, research]
    businessplan: [prd, ux-design]
    techplan: [architecture]
  required_gates:
    phase_completion: informational
    promotion_small_to_medium: hard
    promotion_medium_to_large: hard
    promotion_large_to_base: hard
  sensing_gate_mode: informational    # or "hard" if upgraded
  additional_review_participants: []
  enforce_stories: true
```

**Determinism guarantee (NFR3):** Identical inputs ALWAYS produce identical output. The algorithm is pure function with no side effects.

## Compliance Checking

### `check-compliance`

Evaluate initiative artifacts against the resolved constitution.

**Input:**
```yaml
resolved_constitution: {from resolve-constitution}
initiative_root: foo-bar-auth
phase: businessplan
artifacts_path: _bmad-output/lens-work/initiatives/foo/bar/phases/businessplan/
```

**Algorithm:**

1. Get required artifacts for this phase from resolved constitution
2. Check each required artifact exists at the artifacts path
3. Evaluate each constitutional requirement against initiative state
4. Classify each result: PASS / FAIL / NOT-APPLICABLE

**Output:**
```yaml
compliance_result:
  status: PASS | FAIL
  phase: businessplan
  checks:
    - requirement: "PRD required for businessplan"
      status: PASS
      details: "prd.md exists and is non-empty"
    - requirement: "UX design required for businessplan"
      status: PASS
      details: "ux-design.md (or ux-design-specification.md) exists and is non-empty"
  hard_gate_failures: []
  informational_failures: []
  not_applicable: []
```

### Gate Classification

Each constitutional requirement has a gate type:

| Gate Type | Behavior |
|-----------|----------|
| `hard` | Blocks PR creation — must be resolved |
| `informational` | Warns in PR body — does not block |

Default gate type: `informational` (unless constitution explicitly specifies `hard`).

### NOT-APPLICABLE Rules

Some requirements are skipped based on track type:

| Track | Skipped Requirements |
|-------|---------------------|
| spike | All implementation requirements |
| hotfix | preplan and businessplan artifacts |
| tech-change | preplan artifacts |

## `resolve-context` — Preflight-Level Cache-Aware Wrapper

This operation is the primary entry point called by `preflight.md` and router workflows. It wraps `resolve-constitution` with two caching layers to eliminate redundant file reads.

### Cache Strategy

**Layer 1 — Session cache (zero cost):**
If `session.constitutional_context` is already set in the current agent session, return it immediately. This eliminates duplicate resolution when both preflight and a router workflow call `resolve-context` in the same execution.

**Layer 2 — File cache (fast path):**
Cache the resolved constitution to `_bmad-output/lens-work/personal/.constitution-cache.yaml` with a UTC timestamp. Use branch-aware TTL windows matching the preflight freshness policy:
- `alpha` branch: cache valid for **15 minutes**
- `beta` branch: cache valid for **1 hour**
- Otherwise: cache valid for **today** (daily cadence)

On cache hit (timestamp within TTL and governance files unchanged), load and return the cached result.

**Cache invalidation:** If any governance constitution file has a `git mtime` newer than the cache timestamp, invalidate and re-resolve.

### Algorithm

```yaml
# constitute.resolve-context
# Returns: constitutional_context object

# Layer 1: Session cache
if session.constitutional_context is set and session.constitutional_context.status != "parse_error":
  return session.constitutional_context

# Layer 2: File cache
cache_path = "_bmad-output/lens-work/personal/.constitution-cache.yaml"
if file_exists(cache_path):
  cached = load(cache_path)
  branch = git("branch --show-current")
  ttl_minutes = branch == "alpha" ? 15 : branch == "beta" ? 60 : 1440  # 1440 = daily
  cache_age_minutes = (now_utc - cached.resolved_at).total_minutes()
  governance_changed = git("diff --name-only ${cached.resolved_at} HEAD -- ${governance_path}/constitutions/ 2>/dev/null")
  if cache_age_minutes <= ttl_minutes and governance_changed == "":
    session.constitutional_context = cached.constitutional_context
    return cached.constitutional_context

# Cache miss: resolve fresh
initiative_state = invoke("git-state.current-initiative")
resolve_input = {
  domain: initiative_state.domain,
  service: initiative_state.service,
  repo: initiative_state.repo,        # optional
  language: initiative_state.language # optional
}
constitutional_context = invoke("constitution.resolve-constitution", resolve_input)

# Annotate with preflight gate status
constitutional_context.preflight_status = "OK"
if constitutional_context.gate_mode == "hard":
  if any required gate failed in constitutional_context:
    constitutional_context.preflight_status = "FAIL"
elif constitutional_context.gate_mode == "advisory":
  if any warning in constitutional_context:
    constitutional_context.preflight_status = "WARN"

# Write file cache
write_file(cache_path, {
  resolved_at: ISO_TIMESTAMP_UTC,
  constitutional_context: constitutional_context
})

# Populate session cache
session.constitutional_context = constitutional_context
return constitutional_context
```

### Error Handling

| Error | Response |
|-------|----------|
| No initiative context (bootstrap) | `context_available: false` — caller decides advisory vs. fail |
| Parse error in governance file | `status: "parse_error"` with file and error details |

## Error Handling

| Error | Response |
|-------|----------|
| Governance repo not found | `❌ Governance repo not accessible at {path}. Run /onboard to verify.` |
| Constitution file missing | Use defaults from parent level (org level is always required) |
| Invalid constitution format | `⚠️ Constitution at {level} has invalid format. Using parent level defaults.` |
