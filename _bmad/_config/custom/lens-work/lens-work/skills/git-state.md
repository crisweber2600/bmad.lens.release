# Skill: git-state

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Derive initiative state from git primitives. No runtime state files. This skill replaces v1's `state-management.md` entirely.

**Design Axiom A1:** Git is the only source of truth. No git-ignored runtime state. No `state.yaml`. No `event-log.jsonl`.

## Write Operations

**NONE.** This skill is strictly read-only. All write operations happen through:
- `git-orchestration` skill (branch creation, commits, pushes)
- PR creation (phase completion, promotion)

## Data Sources (read-only)

| Source | Purpose |
|--------|---------|
| `git symbolic-ref --short HEAD` | Current branch → initiative, audience, phase |
| `git branch --list` | Branch existence → what's been started |
| `git log --oneline` | Commit history inspection |
| `git show <branch>:<path>` | Cross-branch config reads without checkout |
| Provider adapter PR queries | Phase completion, promotion status |
| Committed artifacts on current branch | Artifact inventory |

## Queries Available

### `current-initiative`

Parse HEAD branch name to extract initiative root and read initiative config.

**Algorithm:**
```bash
BRANCH=$(git symbolic-ref --short HEAD)
INITIATIVE_ROOT=$(echo "$BRANCH" | sed -E 's/-(small|medium|large|base)(-.*)?$//')
```

**Output:**
```yaml
initiative_root: foo-bar-auth
branch: foo-bar-auth-small-techplan
scope: feature        # derived from config or segment count
config_path: _bmad-output/lens-work/initiatives/foo/bar/auth.yaml
```

**Config path resolution:**
The config path depends on initiative scope (segment count in root):
- 1 segment (domain): `_bmad-output/lens-work/initiatives/{domain}/initiative.yaml`
- 2 segments (service): `_bmad-output/lens-work/initiatives/{domain}/{service}/initiative.yaml`
- 3 segments (feature): `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`

When the config file exists, read the `scope` field to resolve ambiguity.

**Edge cases:**
- Root-only branch (no audience suffix): initiative is at root level
- Non-initiative branch (main, develop): return `null` initiative

---

### `current-phase`

Parse branch name to extract active phase suffix after audience token.

**Algorithm:**
```bash
PHASE=$(echo "$BRANCH" | sed -E 's/^.*-(small|medium|large|base)-//')
# If branch is {root}-{audience} with no phase suffix, PHASE is empty
```

**Output:**
```yaml
phase: techplan
display_name: TechPlan
agent: winston
audience: small
```

**Edge cases:**
- Audience branch with no phase suffix: `phase: null` (between phases)
- Root-only branch: `phase: null`, `audience: null`

---

### `current-audience`

Parse audience token from branch name.

**Algorithm:**
```bash
AUDIENCE=$(echo "$BRANCH" | grep -oE '(small|medium|large|base)')
```

**Output:**
```yaml
audience: small
role: "IC creation work"
```

**Edge cases:**
- No audience token found: on initiative root or non-initiative branch

---

### `phase-status(phase)`

Check PR state for a specific phase to determine completion.

**Algorithm:**
```bash
# Phase complete IFF merged PR exists from phase branch → audience branch
# Uses provider adapter for PR queries
provider-adapter query-pr-status \
  --head "${INITIATIVE_ROOT}-${AUDIENCE}-${PHASE}" \
  --base "${INITIATIVE_ROOT}-${AUDIENCE}" \
  --state merged
```

**Output:**
```yaml
phase: techplan
status: complete    # complete | in-progress | not-started
branch_exists: true
pr_state: merged    # merged | open | closed | none
```

**Derivation rules:**
- Branch does not exist → `not-started`
- Branch exists, no PR → `in-progress`
- Branch exists, PR open → `in-progress` (pending review)
- Branch exists, PR merged → `complete`

---

### `promotion-status(from, to)`

Check PR state for audience-to-audience promotion.

**Algorithm:**
```bash
# Promotion complete IFF merged PR exists from source audience → target audience
provider-adapter query-pr-status \
  --head "${INITIATIVE_ROOT}-${FROM}" \
  --base "${INITIATIVE_ROOT}-${TO}" \
  --state merged
```

**Output:**
```yaml
from: small
to: medium
status: complete    # complete | in-progress | not-started
pr_state: merged    # merged | open | closed | none
```

---

### `active-initiatives(domain?)`

List all active initiative roots, optionally filtered by domain.

**Algorithm:**
```bash
# List all initiative-root branches, deduplicate
git branch -a \
  | sed -E 's/^[*[:space:]]+//' \
  | sed '/^remotes\/origin\/HEAD ->/d' \
  | sed 's#^remotes/origin/##' \
  | sed -E 's/-(small|medium|large|base)(-.*)?$//' \
  | sort -u

# Filter by domain if specified
git branch -a \
  | sed -E 's/^[*[:space:]]+//' \
  | sed '/^remotes\/origin\/HEAD ->/d' \
  | sed 's#^remotes/origin/##' \
  | grep -E "^${DOMAIN}-" \
  | sed -E 's/-(small|medium|large|base)(-.*)?$//' \
  | sort -u
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

## v1 → v2 State Derivation Comparison

| Question | v1 (state.yaml) | v2 (git-derived) |
|----------|-----------------|-------------------|
| Current initiative | `state.yaml → active_initiative` | Parse `git symbolic-ref --short HEAD` |
| Current phase | `state.yaml → current_phase` | Parse branch name suffix after audience |
| Current audience | `state.yaml → current_audience` | Parse branch name for audience token |
| Completed phases | `state.yaml → completed_phases[]` | Query merged PRs via provider adapter |
| Promotion status | `state.yaml → promoted_audiences[]` | Query merged PRs via provider adapter |
| Active initiatives | `state.yaml → initiatives{}` scan | `git branch --list` + parse roots |
| Initiative config | Dual-written (stale) | Committed on initiative branch (single source) |
| Event history | `event-log.jsonl` (git-ignored, lost) | PR descriptions + commit messages |

## Dependencies

- `lifecycle.yaml` — for valid audience tokens and phase names
- Provider adapter (skills/provider-adapter.md) — for PR state queries
