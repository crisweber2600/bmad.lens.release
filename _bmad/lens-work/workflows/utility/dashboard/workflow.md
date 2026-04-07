# Dashboard Workflow

**Command:** `/dashboard` (DB)
**Type:** Utility — read-only
**Added:** v3.1

## Purpose

Generate a consolidated multi-initiative status view showing all active initiatives
across domains with current phase, milestone, blocking PRs, and sensing alerts.
Replaces the need to `/switch` + `/status` repeatedly.

## Trigger

User runs `/dashboard` or the agent determines multi-initiative context is needed.

## Inputs

| Input | Source | Required |
|-------|--------|----------|
| All initiative branches | `git branch --list` | Yes |
| Open PRs | Provider adapter | Yes |
| Committed artifacts | `git show` per branch | Yes |
| Sensing data | Cross-initiative skill | Optional |

## Algorithm

### Step 1: Enumerate Active Initiatives

```
git branch --list | grep initiative patterns
```

For each branch matching `{domain}-{service}-{feature}*`:
- Extract initiative root from branch name
- Determine current milestone from branch suffix
- Read `initiative.yaml` from initiative root branch

### Step 2: Derive State Per Initiative

For each initiative:
1. **Phase**: Determine current phase from committed artifacts on milestone branch
2. **Milestone**: Current milestone branch (highest existing)
3. **Blocking PRs**: Query provider for open PRs matching branch patterns
4. **Last Activity**: Most recent commit timestamp on milestone branch
5. **Track**: Read from `initiative.yaml`
6. **Sensing**: Run lightweight overlap check

### Step 3: Generate Mermaid Dashboard

```mermaid
flowchart TB
    subgraph domain-payments["🏢 payments"]
        subgraph service-gateway["🔧 gateway"]
            INIT1["payments-gateway-oauth<br/>📍 devproposal · track: full<br/>⏳ PR #42 awaiting review"]
            INIT2["payments-gateway-retry<br/>📍 techplan · track: tech-change<br/>✅ No blockers"]
        end
        subgraph service-ledger["🔧 ledger"]
            INIT3["payments-ledger-v2<br/>📍 sprintplan · track: feature<br/>⚠️ Sensing: overlap with gateway-oauth"]
        end
    end

    subgraph domain-identity["🏢 identity"]
        subgraph service-auth["🔧 auth"]
            INIT4["identity-auth-mfa<br/>📍 preplan · track: full<br/>✅ No blockers"]
        end
    end
```

### Step 4: Generate Table Summary

```markdown
| # | Initiative | Domain | Service | Track | Phase | Milestone | Blocking PRs | Sensing | Last Activity |
|---|-----------|--------|---------|-------|-------|-----------|-------------|---------|--------------|
| 1 | gateway-oauth | payments | gateway | full | devproposal | devproposal | PR #42 | — | 2h ago |
| 2 | gateway-retry | payments | gateway | tech-change | techplan | techplan | — | — | 1d ago |
| 3 | ledger-v2 | payments | ledger | feature | sprintplan | sprintplan | — | ⚠️ overlap | 4h ago |
| 4 | auth-mfa | identity | auth | full | preplan | techplan | — | — | 3d ago |
```

### Step 5: Surface Recommendations

Based on dashboard state, recommend:
- Initiatives with stale PRs (> 48h without review)
- Sensing conflicts requiring attention
- Initiatives ready for `/promote`
- Initiatives idle for > 7 days

### Step 6: Cross-Feature Visibility Layer *(v3.3)*

When `features_registry.enabled` in lifecycle.yaml, augment the dashboard with
relationship and staleness data sourced from `feature-index.yaml` on main.

#### 6a. Dependency Graph

Read all `relationships` from feature-index.yaml. Render a Mermaid dependency graph
showing `depends_on` (solid arrows) and `blocks` (dashed arrows):

```mermaid
flowchart LR
    A["payments-gateway-oauth"] -->|depends_on| B["identity-auth-mfa"]
    A -.->|blocks| C["payments-ledger-v2"]
    D["payments-gateway-retry"] -->|related| A
```

Rules:
- `depends_on` → solid arrow from dependent to dependency
- `blocks` → dashed arrow from blocker to blocked feature
- `related` → dotted arrow, informational only
- Color nodes by status: draft=gray, planning=blue, developing=green, blocked=red, done=dimgray

#### 6b. Staleness Alerts

For each initiative with `context.stale == true` in its initiative-state.yaml,
append a warning row in the recommendations section:

```
⚠️ Stale cross-feature context:
  - payments-gateway-oauth: context pulled 3d ago, identity-auth-mfa updated since
  - payments-ledger-v2: context pulled 5d ago, gateway-oauth updated since
```

#### 6c. Portfolio Summary From Feature Index

Add a compact portfolio table sourced entirely from feature-index.yaml (no branch
switching needed):

```markdown
| Feature | Domain | Service | Status | Owner | Dependencies | Last Updated |
|---------|--------|---------|--------|-------|-------------|-------------|
| gateway-oauth | payments | gateway | developing | @alice | identity-auth-mfa | 2h ago |
| auth-mfa | identity | auth | planning | @bob | — | 1d ago |
```

This table complements Step 4 by providing the "main branch truth" view that does
not require initiative branches to exist.

## Outputs

| Output | Format | Location |
|--------|--------|----------|
| Dashboard report | Markdown + Mermaid | Console (not committed) |

## Error Handling

- No initiatives found: Show onboarding guidance
- Provider API unavailable: Show branch-only view (no PR data)
- Large initiative count: Group by domain, paginate services
