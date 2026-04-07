]633;E;echo '---';1f0482a0-f773-402e-9b8d-02ad2949aad3]633;C---
name: lens-work-git-state
description: "Derive initiative state from git primitives — read-only queries. Use when querying initiative state or branch status."
---

# Skill: git-state

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Derive initiative state from git primitives and committed YAML state. `initiative-state.yaml` is the single source of truth for runtime state. This skill replaces v1's `state-management.md` entirely.

**Design Axiom A1:** Git is the only source of truth. No git-ignored runtime state. No `event-log.jsonl`.

## Write Operations

**NONE.** This skill is strictly read-only. All write operations happen through:
- `git-orchestration` skill (branch creation, commits, pushes)
- PR creation (phase completion, promotion)

## Data Sources (read-only)

| Source | Purpose |
|--------|---------|
| `git symbolic-ref --short HEAD` | Current branch → active initiative lookup key |
| `git branch --list` | Branch existence → what's been started |
| `git log --oneline` | Commit history inspection |
| `git show <branch>:<path>` | Cross-branch config reads without checkout |
| Provider adapter PR queries | Phase completion, promotion status |
| Committed artifacts on current branch | Artifact inventory |

## Queries Available

### `current-initiative`

Resolve the active initiative from the current branch and read its committed state file.

**Algorithm:**
```bash
BRANCH=$(git symbolic-ref --short HEAD)
# Branch name is a lookup key only. Use the active initiative config and committed
# initiative-state.yaml to resolve the matching initiative record.
```

**Output:**
```yaml
initiative_root: foo-bar-auth
branch: foo-bar-auth-techplan
scope: feature
config_path: _bmad-output/lens-work/initiatives/foo/bar/auth.yaml
state_path: _bmad-output/lens-work/initiatives/foo/bar/auth/initiative-state.yaml
```

**Config path resolution:**
The config path depends on initiative scope (segment count in root):
- 1 segment (domain): `_bmad-output/lens-work/initiatives/{domain}/initiative.yaml`
- 2 segments (service): `_bmad-output/lens-work/initiatives/{domain}/{service}/initiative.yaml`
- 3 segments (feature): `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`

When the config file exists, read the `scope` field to resolve ambiguity.

**Edge cases:**
- Root-only branch (no milestone suffix): initiative is at root level
- Non-initiative branch (main, develop): return `null` initiative
- Missing `initiative-state.yaml`: fall back to legacy branch-suffix detection and warn the user to run `/lens-upgrade`

---

### `current-phase`

Read the active phase directly from `initiative-state.yaml`.

**Algorithm:**
```bash
# Read initiative-state.yaml for the active initiative.
# Use state.phase as the authoritative current phase.
```

**Output:**
```yaml
phase: techplan
display_name: TechPlan
agent: winston
milestone: techplan
```

**Edge cases:**
- Missing `initiative-state.yaml`: fall back to legacy branch-suffix detection and warn the user
- Root-only branch: `phase: null`, `milestone: null`

---

### `current-milestone`

Read the active milestone directly from `initiative-state.yaml`.

**Algorithm:**
```bash
# Read initiative-state.yaml for the active initiative.
# Use state.milestone as the authoritative branch milestone token.
```

**Output:**
```yaml
milestone: techplan
role: "IC creation work"
```

**Edge cases:**
- No `initiative-state.yaml` found: warn and fall back to legacy branch-suffix detection

---

### `phase-status(phase)`

Read initiative state for a specific phase to determine completion.

**Algorithm:**
```bash
# Read initiative-state.yaml for the active initiative.
# A phase is complete when artifacts.${PHASE} exists or the current state has advanced beyond
# ${PHASE} with phase_status == complete on the same milestone chain.
# Commit markers remain an audit trail, not the primary query path.
```

**Output:**
```yaml
phase: techplan
milestone: techplan
status: complete    # complete | in-progress | not-started
state_source: initiative-state.yaml
```

**Derivation rules:**
- `artifacts.${PHASE}` exists or current phase moved past `${PHASE}` with completed status → `complete`
- Current phase equals `${PHASE}` and `phase_status == in-progress` → `in-progress`
- No recorded phase state yet → `not-started`

---

### `promotion-status(from, to)`

Check PR state for milestone-to-milestone promotion.

**Algorithm:**
```bash
# Promotion complete IFF merged PR exists from source milestone → target milestone
provider-adapter query-pr-status \
  --head "${INITIATIVE_ROOT}-${FROM}" \
  --base "${INITIATIVE_ROOT}-${TO}" \
  --state merged
```

**Output:**
```yaml
from: techplan
to: devproposal
status: complete    # complete | in-progress | not-started
pr_state: merged    # merged | open | closed | none
```

---

### `active-initiatives(domain?)`

List all active initiative roots, optionally filtered by domain.

**Algorithm:**
```bash
# Enumerate committed initiative-state.yaml files under:
# _bmad-output/lens-work/initiatives/
# Filter by lifecycle_status == active and optionally by domain.
# Branch scanning is not the discovery mechanism in v3.
```

**Output:**
```yaml
initiatives:
  - root: foo-bar-auth
    domain: foo
    service: bar
    scope: feature
  - root: foo-car-api
    domain: foo
    service: car
    scope: feature
  - root: payments
    domain: payments
    service: null
    scope: domain
  - root: payments-billing
    domain: payments
    service: billing
    scope: service
```

---

### `cross-feature-context(initiative_root)` *(v3.3)*

Read `feature-index.yaml` from main, resolve relationships for the current feature, and fetch the appropriate depth of cross-feature context. This is the core capability powering Pain Point 5 (Cross-Feature Visibility).

**Design principle:** Relationship type drives fetch depth automatically. No user action required.

**Algorithm:**
```bash
# 1. Read feature-index.yaml from main (no checkout, no local state change)
FEATURE_INDEX=$(git show origin/main:_bmad-output/lens-work/feature-index.yaml 2>/dev/null)
if [ -z "$FEATURE_INDEX" ]:
  return { status: "unavailable", reason: "feature-index.yaml not found on main" }

# 2. Look up the current feature in the index
CURRENT_FEATURE = parse_yaml(FEATURE_INDEX).features[initiative_root]
if CURRENT_FEATURE is null:
  return { status: "not_indexed", reason: "Feature '${initiative_root}' not in feature-index.yaml" }

# 3. Classify relationships and determine fetch depth
CONTEXT = { related: [], depends_on: [], blocks: [] }

for rel_type in [depends_on, blocks, related]:
  for target_feature in CURRENT_FEATURE.relationships[rel_type]:
    TARGET_ENTRY = parse_yaml(FEATURE_INDEX).features[target_feature]
    if TARGET_ENTRY is null:
      CONTEXT[rel_type].append({
        feature: target_feature,
        status: "unknown",
        warning: "Referenced feature not found in feature-index.yaml"
      })
      continue

    if rel_type == "related":
      # Fetch summary only from main � lightweight
      SUMMARY = git show origin/main:${summary_file_pattern(TARGET_ENTRY)} 2>/dev/null || "No summary available"
      CONTEXT.related.append({
        feature: target_feature,
        domain: TARGET_ENTRY.domain,
        service: TARGET_ENTRY.service,
        status: TARGET_ENTRY.status,
        updated_at: TARGET_ENTRY.updated_at,
        summary: SUMMARY
      })

    if rel_type in ["depends_on", "blocks"]:
      # Fetch FULL planning docs from plan branch � proactive, zero user action
      PLAN_BRANCH = TARGET_ENTRY.plan_branch || "${target_feature}-plan"
      DOCS = {}
      for doc_type in ["tech-plan.md", "architecture.md", "prd.md", "product-brief.md"]:
        DOC_PATH = "_bmad-output/lens-work/initiatives/${TARGET_ENTRY.domain}/${TARGET_ENTRY.service}/"
        DOC_CONTENT = git show origin/${PLAN_BRANCH}:${DOC_PATH}${doc_type} 2>/dev/null
        if DOC_CONTENT is not null:
          DOCS[doc_type] = DOC_CONTENT
      CONTEXT[rel_type].append({
        feature: target_feature,
        domain: TARGET_ENTRY.domain,
        service: TARGET_ENTRY.service,
        status: TARGET_ENTRY.status,
        updated_at: TARGET_ENTRY.updated_at,
        plan_branch: PLAN_BRANCH,
        docs: DOCS
      })
```

**Output:**
```yaml
cross_feature_context:
  feature: auth-refresh
  index_read_at: "{timestamp}"
  relationships:
    depends_on:
      - feature: token-rotation
        domain: platform
        service: identity
        status: dev
        updated_at: "2026-04-03T10:00:00Z"
        plan_branch: token-rotation-plan
        docs:
          tech-plan.md: "{full document content}"
          architecture.md: "{full document content}"
    blocks:
      - feature: session-mgmt
        domain: platform
        service: identity
        status: planning
        updated_at: "2026-04-01T08:00:00Z"
        plan_branch: session-mgmt-plan
        docs:
          prd.md: "{full document content}"
    related:
      - feature: user-profile
        domain: platform
        service: identity
        status: dev
        updated_at: "2026-04-04T12:00:00Z"
        summary: "User profile management � avatar upload, display name, email preferences"
  staleness:
    context_last_pulled: "2026-04-03T10:00:00Z"    # from initiative-state.yaml
    stale_features: ["token-rotation"]               # features updated since last pull
    is_stale: true
```

**Relationship fetch depth:**

| Relationship | What is fetched | Source |
|---|---|---|
| `related` | Summary only | `git show origin/main:...summary.md` |
| `depends_on` | Full planning docs | `git show origin/{plan_branch}:...` |
| `blocks` | Full planning docs of blocked feature | `git show origin/{plan_branch}:...` |

**Staleness detection (v3.3):**
```yaml
# After fetching context, compare against initiative-state.yaml context.last_pulled
STATE = read("initiative-state.yaml")
LAST_PULLED = STATE.context.last_pulled || null

stale_features = []
for rel_type in [depends_on, blocks, related]:
  for entry in CONTEXT[rel_type]:
    if LAST_PULLED is null or entry.updated_at > LAST_PULLED:
      stale_features.append(entry.feature)

if stale_features.length > 0:
  staleness.is_stale = true
  staleness.stale_features = stale_features
  warning: "?? Cross-feature context is stale. Features updated since last pull: ${stale_features.join(', ')}"
```

**Edge cases:**
- `feature-index.yaml` not found on main: return `{ status: "unavailable" }` � non-fatal
- Feature not in index: return `{ status: "not_indexed" }` � non-fatal, likely new feature
- Related feature's plan branch doesn't exist: skip doc fetch, include summary from main only
- No relationships defined: return empty context with `is_stale: false`
- Governance repo not configured: read from current repo's main branch instead

**Segment parsing:**
- 1 segment: domain-only initiative (scope: domain, service: null)
- 2 segments: service-level initiative (scope: service)
- 3+ segments: feature-level initiative (scope: feature)

When config is available, prefer the `scope` field over segment counting.

---

### `initiative-config(root)`

Read initiative config from a specific branch without switching HEAD.

**Algorithm:**
```bash
# Read config from the initiative root branch
# Path depends on scope — try each pattern or read scope from config
git show "${ROOT}:_bmad-output/lens-work/initiatives/${DOMAIN}/initiative.yaml"        # domain scope
git show "${ROOT}:_bmad-output/lens-work/initiatives/${DOMAIN}/${SERVICE}/initiative.yaml"  # service scope
git show "${ROOT}:_bmad-output/lens-work/initiatives/${DOMAIN}/${SERVICE}/${FEATURE}.yaml"  # feature scope
```

**Output:**
```yaml
initiative: auth
scope: feature
domain: foo
service: bar
track: full
language: typescript
created: 2026-03-08T10:00:00Z
initiative_root: foo-bar-auth
```

---

### `artifact-inventory(initiative, phase)`

List files in a specific phase directory on the current or specified branch.

**Algorithm:**
```bash
# List artifacts for a phase
git show "${BRANCH}:_bmad-output/lens-work/initiatives/${DOMAIN}/${SERVICE}/phases/${PHASE}/" 2>/dev/null
# Or on current branch:
ls _bmad-output/lens-work/initiatives/${DOMAIN}/${SERVICE}/phases/${PHASE}/
```

**Output:**
```yaml
phase: techplan
artifacts:
  - architecture.md
artifact_count: 1
```

---

## v2 → v3 State Derivation Comparison

| Question | v2 (git-derived) | v3 (initiative-state.yaml) |
|----------|-------------------|
| Current initiative | Parse `git symbolic-ref --short HEAD` | Branch lookup key only; read `initiative-state.yaml` |
| Current phase | Parse branch suffix | Read `initiative-state.yaml.phase` |
| Current milestone | N/A | Read `initiative-state.yaml.milestone` |
| Completed phases | Query merged PRs via provider adapter | Provider PRs + committed phase markers |
| Promotion status | Query merged PRs via provider adapter | Provider PRs + milestone branch merge status |
| Active initiatives | `git branch --list` + parse roots | Enumerate `_bmad-output/lens-work/initiatives/**/initiative-state.yaml` |
| Initiative config | Dual-written (stale) | Committed on initiative branch (single source) |
| Event history | `event-log.jsonl` (git-ignored, lost) | PR descriptions + commit messages |

## Dependencies

- `lifecycle.yaml` — for valid milestone tokens and phase names
- `initiative-state.yaml` — for authoritative initiative runtime state
- `git-orchestration` skill (provider adapter section) — for PR state queries
