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
