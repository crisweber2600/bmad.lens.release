# Skill: sensing

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Detect overlapping initiatives at lifecycle gates by analyzing git branch topology. Produces sensing reports that surface cross-initiative conflicts before they cause problems.

**Design Axiom A4:** Sensing must be automatic at lifecycle gates, not manual discovery.
**Design Axiom A1:** Git is the only source of truth — sensing reads from git branches, no external state.

## Write Operations

**NONE.** This skill is strictly read-only. It reads branch names and committed configs. It produces a report string — it does NOT block anything by itself. The constitution can upgrade sensing to a hard gate for specific domains.

## Trigger Points

| Trigger | Context |
|---------|---------|
| `/new-domain`, `/new-service`, `/new-feature` | Pre-creation check — warn if overlapping initiatives exist |
| `/promote` | Pre-promotion gate — sensing report embedded in promotion PR |
| `/sense` | On-demand — user explicitly requests sensing report |

## Operations

### `scan-initiatives`

List all active initiatives and identify overlaps with the current initiative.

**Input:**
```yaml
current_domain: payments
current_service: auth        # optional — null for domain-level initiatives
current_feature: oauth       # optional — null for service or domain-level
```

**Algorithm:**

1. List all remote branches: `git branch -r`
2. Filter branches matching initiative naming patterns (exclude non-initiative branches like `main`, `develop`, `feature/*`)
3. Parse each branch name to extract:
   - `initiative_root`: everything before the audience token
   - `domain`: first segment of the root
   - `service`: second segment of the root (if present)
   - `feature`: third segment of the root (if present)
   - `audience`: the audience token (small/medium/large/base)
   - `phase`: the phase suffix (if present)
4. Group parsed branches by initiative root (deduplicate — multiple branches per initiative)
5. For each unique initiative, determine:
   - Current audience (highest audience branch that exists)
   - Current phase (phase branch suffix, if any)
   - Track type (read from committed init config if accessible)

6. Identify overlapping initiatives:
   - **Same domain:** initiatives sharing the `domain` segment
   - **Same service:** initiatives sharing the `domain`+`service` segments
   - **Same feature:** initiatives targeting the same feature (high conflict)

7. Classify conflict potential:

| Overlap Type | Conflict Level | Description |
|-------------|---------------|-------------|
| Same feature | 🔴 High | Direct file/scope overlap likely |
| Same service | 🟡 Medium | Shared service boundary, possible conflict |
| Same domain | 🟢 Low | Same domain but different services |

**Output:**
```yaml
sensing_report:
  scanned_at: "{timestamp}"
  current_initiative: "{initiative_root}"
  total_initiatives_scanned: {count}
  overlaps:
    - initiative: "{overlapping_root}"
      domain: "{domain}"
      service: "{service}"
      audience: "{audience}"
      phase: "{phase}"
      conflict_level: "high|medium|low"
      conflict_reason: "Same service — possible scope overlap"
  summary: "⚠️ Active initiatives in domain `{domain}`: `{init-1}` ({phase}/{audience}), `{init-2}` ({phase}/{audience})"
```

### `format-report`

Format the sensing results for display.

**When overlaps found:**
```
⚠️ Active initiatives in domain `{domain}`:
  🔴 `{init-1}` ({phase}/{audience}) — same service (high conflict)
  🟡 `{init-2}` ({phase}/{audience}) — same domain (medium conflict)

Suggestion: Review overlapping initiatives before proceeding.
```

**When no overlaps found:**
```
No overlapping initiatives detected ✅
```

**When sensing is a hard gate (constitution-upgraded):**
```
⚠️ REQUIRES EXPLICIT CONFLICT REVIEW

Active initiatives in domain `{domain}`:
  🔴 `{init-1}` ({phase}/{audience}) — same service (high conflict)

Constitution requires explicit conflict resolution for this domain.
```

## Branch Naming Pattern

Sensing relies on the branch naming convention defined in lifecycle.yaml:

```
{domain}-{service}-{feature}-{audience}[-{phase}]
```

Examples:
```
payments-auth-oauth-small-preplan      → domain:payments, service:auth, feature:oauth, audience:small, phase:preplan
payments-auth-oauth-small              → domain:payments, service:auth, feature:oauth, audience:small, phase:null
payments-billing-invoicing-medium      → domain:payments, service:billing, feature:invoicing, audience:medium
infra-cicd-pipeline-small-techplan     → domain:infra, service:cicd, feature:pipeline, audience:small, phase:techplan
```

## Error Handling

| Error | Response |
|-------|----------|
| No remote branches found | `⚠️ No remote branches found. Ensure remote is configured.` |
| Cannot parse branch name | Skip branch silently (non-initiative branch) |
| Cannot read initiative config | Include initiative with "config unavailable" note |

## Dependencies

- `git branch -r` — for listing all remote branches
- Branch naming conventions from `lifecycle.yaml`
- `git show {branch}:{path}` — for reading committed initiative configs (optional)
- `constitution` skill — for checking if sensing is a hard gate (called by consumer, not by this skill)
