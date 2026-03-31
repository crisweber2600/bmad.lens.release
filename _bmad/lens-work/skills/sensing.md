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

## Execution Model

Sensing runs two passes:

1. **Pass 1 — Live branch conflicts:** Scans git branch topology for active initiative overlaps (always runs)
2. **Pass 2 — Historical governance context:** Reads `governance:artifacts/` for completed initiatives in the same domain/service (runs only when governance is configured)

Pass 2 is strictly additive. If governance is unavailable, Pass 1 results are returned unchanged with a note.
List all active initiatives and identify overlaps with the current initiative.

**Input:**
```yaml
current_domain: payments
current_service: auth        # null for domain-level initiatives
current_feature: oauth       # null for service or domain-level initiatives
current_scope: feature       # domain | service | feature
```

**Algorithm:**

1. List all remote branches: `git branch -r`
2. Filter branches matching initiative naming patterns (exclude non-initiative branches like `main`, `develop`, `feature/*`)
3. Parse each branch name to extract:
   - `initiative_root`: everything before the audience token
   - `domain`: first segment of the root
   - `service`: second segment of the root (if present; null for domain-only roots)
   - `feature`: third segment of the root (if present; null for domain or service-level roots)
   - `audience`: the audience token (small/medium/large/base)
   - `phase`: the phase suffix (if present)
4. Group parsed branches by initiative root (deduplicate — multiple branches per initiative)
5. For each unique initiative, determine:
   - Current audience (highest audience branch that exists)
   - Current phase (phase branch suffix, if any)
   - Track type (read from committed init config if accessible)
   - **Lifecycle status** (read from committed `initiative-state.yaml` if accessible)

5a. **Filter closed initiatives from live conflicts:**
   ```yaml
   for each initiative:
     state_yaml = git show ${initiative_root}:initiative-state.yaml 2>/dev/null
     if state_yaml exists:
       if state_yaml.lifecycle_status != "active":
         # Exclude from Pass 1 overlap detection — closed initiatives are not active conflicts
         mark initiative as "closed" and skip overlap classification
         continue
     else:
       # No initiative-state.yaml (legacy v2) — treat as active (conservative fallback)
       # Append note: "⚠️ No initiative-state.yaml — treating as active. Consider running /lens-upgrade"
   ```

6. Identify overlapping initiatives (only among active initiatives):
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
  historical_context:
    status: "available|unavailable"
    initiatives: []    # populated by scan-governance-history pass 2
    note: ""           # set when governance unavailable
  summary: "⚠️ Active initiatives in domain `{domain}`: `{init-1}` ({phase}/{audience}), `{init-2}` ({phase}/{audience})"
```

8. **Pass 2 — Governance history enrichment:**
   ```yaml
   governance_result = invoke: sensing.scan-governance-history
   params:
     current_domain: ${current_domain}
     current_service: ${current_service}

   if governance_result.status == "available":
     sensing_report.historical_context.status = "available"
     sensing_report.historical_context.initiatives = governance_result.historical_initiatives
   else:
     sensing_report.historical_context.status = "unavailable"
     sensing_report.historical_context.note = "Governance artifact history unavailable (${governance_result.reason})"
   ```

### `format-report`

Format the sensing results for display. Report structure is always:
**[Live Conflicts]** → **[Historical Context]** → **[Summary]**

Pass 2 (Historical Context) **never** fails the gate — all governance errors are advisory only.

**Full report template:**
```
═══════════════════════════════════════
  SENSING REPORT — ${current_initiative}
  Scanned: ${scanned_at}
═══════════════════════════════════════

── Live Conflicts (Pass 1) ──────────

${if overlaps.length > 0}
⚠️ Active initiatives in domain `{domain}`:
  🔴 `{init-1}` ({phase}/{milestone}) — same service (high conflict)
  🟡 `{init-2}` ({phase}/{milestone}) — same domain (medium conflict)

Suggestion: Review overlapping initiatives before proceeding.
${else}
No overlapping initiatives detected ✅
${endif}

${if constitution_hard_gate}
⚠️ REQUIRES EXPLICIT CONFLICT REVIEW
Constitution requires explicit conflict resolution for this domain.
${endif}

── Historical Context (Pass 2) ──────

${if historical_context.status == "available" and historical_context.initiatives.length > 0}
📚 Prior initiatives in ${domain}/${service}:
  `${init.initiative}` — milestone: ${init.milestone}, published: ${init.published_at}
    Path: governance:artifacts/${init.domain}/${init.service}/${init.initiative}/
    Artifacts: ${init.artifacts.join(', ')}
${elif historical_context.status == "available"}
No prior initiatives found in governance for ${domain}/${service}
${else}
ℹ️ Governance artifact history unavailable (${historical_context.note})
${endif}

── Summary ──────────────────────────

Live conflicts: ${overlaps.length}
Historical initiatives: ${historical_context.initiatives.length || 0}
Total scanned: ${total_initiatives_scanned}
```

---

### `scan-governance-history`

Read completed-initiative context from governance artifacts as a second-pass enrichment. This pass is additive — it never replaces or modifies Pass 1 (branch-based) results.

**Input:**
```yaml
current_domain: payments
current_service: auth
```

**Algorithm:**

1. Check if governance remote is configured:
   ```bash
   GOVERNANCE_REPO = resolve_governance_repo_path()
   if not GOVERNANCE_REPO:
     return { status: "unavailable", reason: "governance_not_configured" }
   ```

2. Read governance artifact directories for the current domain/service:
   ```bash
   cd "${GOVERNANCE_REPO}"
   governance_root = load("lifecycle.yaml").artifact_publication.governance_root
   search_path = "${governance_root}${current_domain}/${current_service}/"

   if not exists(search_path):
     return { status: "available", historical_initiatives: [] }

   # List all initiative directories under the service path
   completed_initiatives = list_dirs(search_path)
   ```

3. For each completed initiative, load `_manifest.yaml`:
   ```bash
   historical_context = []
   for init_dir in completed_initiatives:
     manifest_path = "${search_path}${init_dir}/_manifest.yaml"
     if exists(manifest_path):
       manifest = load(manifest_path)
       historical_context.append({
         initiative: manifest.initiative,
         domain: manifest.domain,
         service: manifest.service,
         milestone: manifest.milestone,
         published_at: manifest.published_at,
         lens_version: manifest.lens_version,
         artifact_count: len(manifest.artifacts),
         artifacts: manifest.artifacts
       })
   ```

**Output:**
```yaml
status: available          # available | unavailable
historical_initiatives:
  - initiative: "payments-auth-oauth"
    domain: payments
    service: auth
    milestone: dev-ready
    published_at: '2026-02-15T10:00:00Z'
    artifact_count: 6
    artifacts: [product-brief.md, prd.md, architecture.md, ...]
  - initiative: "payments-auth-mfa"
    domain: payments
    service: auth
    milestone: sprintplan
    published_at: '2026-03-01T14:00:00Z'
    artifact_count: 4
    artifacts: [product-brief.md, prd.md, ...]
```

## Verification Scenarios

The following scenarios define the expected sensing behavior across governance configurations. All three must produce valid reports without errors.

### Scenario 1: Governance Remote Absent

**Precondition:** Governance remote is not configured (no governance repo path resolvable)

**Expected behavior:**
- Pass 1 (branch conflict scan) runs normally
- Pass 2 is skipped entirely — `scan-governance-history` returns `{ status: "unavailable", reason: "governance_not_configured" }`
- Report Historical Context section displays: `ℹ️ Governance artifact history unavailable (governance_not_configured)`
- No error is thrown. Sensing gate passes based on Pass 1 alone.

### Scenario 2: Governance Configured, No Artifacts

**Precondition:** Governance remote is configured and reachable, but `artifacts/{domain}/{service}/` directory does not exist

**Expected behavior:**
- Pass 1 runs normally
- Pass 2 runs — `scan-governance-history` finds no `search_path`, returns `{ status: "available", historical_initiatives: [] }`
- Report Historical Context section displays: `No prior initiatives found in governance for {domain}/{service}`
- No error is thrown.

### Scenario 3: Governance Configured With Data

**Precondition:** Governance remote is configured and `artifacts/{domain}/{service}/{initiative}/` contains a valid `_manifest.yaml`

**Expected behavior:**
- Pass 1 runs normally
- Pass 2 runs — `scan-governance-history` loads `_manifest.yaml` for each initiative directory
- Report Historical Context section lists each initiative with: initiative name, milestone, published_at, governance path link, artifact list
- Example output line:
  ```
  `payments-auth-oauth` — milestone: dev-ready, published: 2026-02-15T10:00:00Z
    Path: governance:artifacts/payments/auth/payments-auth-oauth/
    Artifacts: product-brief.md, prd.md, architecture.md
  ```

### Cross-Scenario Invariants

- Pass 1 **always** runs regardless of governance state
- Pass 2 failures or absences **never** fail the sensing gate
- The report **always** contains all three sections: [Live Conflicts], [Historical Context], [Summary]
- The Summary section always shows `Historical initiatives: 0` when governance is unavailable or empty

---

## Branch Naming Pattern

Sensing relies on the branch naming convention defined in lifecycle.yaml. **Initiative roots have variable segment counts depending on scope:**

```
{domain}                                   # domain-level root
{domain}-{service}                         # service-level root
{domain}-{service}-{feature}               # feature-level root
{root}-{audience}                          # audience branch
{root}-{audience}-{phase}                  # phase branch
```

Examples:
```
test-worker-small                          → domain:test, service:worker, feature:null, audience:small, phase:null
test-worker-small-preplan                  → domain:test, service:worker, feature:null, audience:small, phase:preplan
payments-auth-oauth-small-preplan          → domain:payments, service:auth, feature:oauth, audience:small, phase:preplan
payments-auth-oauth-small                  → domain:payments, service:auth, feature:oauth, audience:small, phase:null
payments-billing-invoicing-medium          → domain:payments, service:billing, feature:invoicing, audience:medium
```

> **Note:** Domain branches never have audience suffixes. A bare `test` branch is the domain root — it never appears as `test-small`.

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
- Governance repo path — resolved via `lifecycle.yaml.artifact_publication.governance_root` (optional; Pass 2 skipped when absent)
- `_manifest.yaml` in governance artifact directories — for historical initiative context (Pass 2)
