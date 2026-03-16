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

## Error Handling

| Error | Response |
|-------|----------|
| Governance repo not found | `❌ Governance repo not accessible at {path}. Run /onboard to verify.` |
| Constitution file missing | Use defaults from parent level (org level is always required) |
| Invalid constitution format | `⚠️ Constitution at {level} has invalid format. Using parent level defaults.` |
