# LENS Workbench — Lifecycle Reference Guide

**Module:** lens-work v3.2  
**Schema:** 3.2  
**Purpose:** Human-readable reference for the lens-work lifecycle system

---

## Overview

The LENS Workbench manages software initiatives through a structured lifecycle of **phases** and **audience tiers**. All state is derived from git — branch existence, PR metadata, and committed artifacts. There is no secondary state store.

## Core Concepts

### Initiatives

An initiative is a unit of work scoped to a domain, service, or feature. Each initiative has its own branch topology in the control repo. **Initiative roots have variable segment counts depending on scope.**

| Scope | Example Root | Created By | Segments |
|-------|-------------|-----------|----------|
| Domain | `test` | `/new-domain` | 1 |
| Service | `test-worker` | `/new-service` | 2 |
| Feature | `test-worker-oauth` | `/new-feature` | 3 |

### Phases

Phases are sequential stages of planning and implementation. Each phase produces artifacts, and phase completion is marked by a merged PR from the phase branch to its audience branch.

| Phase | Agent | Artifacts Produced |
|-------|-------|--------------------|
| PrePlan | Mary (Analyst) | product-brief, research, brainstorm |
| BusinessPlan | John (PM) + Sally (UX) | prd, ux-design |
| TechPlan | Winston (Architect) | architecture |
| DevProposal | John (PM) | epics, stories, implementation-readiness |
| SprintPlan | Bob (Scrum Master) | sprint-status, story-files |

### Audience Tiers

Audiences represent levels of review and approval. Initiatives start at `small` and promote upward through PR-based gates.

| Audience | Role | Entry Gate | Phases Worked |
|----------|------|-----------|---------------|
| small | IC creation work | — | preplan, businessplan, techplan |
| medium | Lead review | Adversarial review (party mode) | devproposal |
| large | Stakeholder approval | Stakeholder approval | sprintplan |
| base | Ready for execution | Constitution gate | — (dev happens in target projects) |
| dev-complete | Execution complete | Dev-completion review | — (signals dev work finished) |

> **v3.1:** The `dev-complete` milestone closes the gap between `base` (dev-ready) and the close workflow. It confirms all target-project dev work is finished and triggers the `/close` flow.

> **Note:** Domains never have audience branches. Audiences apply only to service-level and feature-level initiatives. A domain branch is the bare root (e.g., `test`), with no `-small` suffix.

### Tracks

Tracks are predefined lifecycle profiles that determine which phases apply.

| Track | Phases | Use Case |
|-------|--------|----------|
| full | preplan → businessplan → techplan → devproposal → sprintplan | Complete lifecycle |
| feature | businessplan → techplan → devproposal → sprintplan | Known business context |
| tech-change | techplan → sprintplan | Pure technical change |
| hotfix | techplan | Urgent fix |
| hotfix-express | techplan | Critical fix — bypasses constitution gate and adversarial review |
| spike | preplan | Research only |
| quickdev | devproposal | Rapid execution |
| express | expressplan | Solo/small team — all planning in one session, no milestone branches, no PRs |

> **v3.1:** The `hotfix-express` track is an expedited path for critical production fixes. It skips the constitution gate and adversarial review while still requiring a technical plan. The constitution controls which teams/repos may use this track.

> **v3.2:** The `express` track combines all planning into a single `expressplan` phase. No milestone branches are created, no PRs are required, and gates are informational only. Ideal for solo developers or small features that don't need multi-phase ceremony.

## Branch Topology

### Naming Convention

Two naming conventions are supported (configured via `lifecycle.yaml → planning_repo.branch_patterns.naming_convention`):

**DSF (domain-service-feature) — default:**
```
{domain}-{service}-{feature}                          # Initiative root
{domain}-{service}-{feature}-{audience}               # Audience branch
{domain}-{service}-{feature}-{audience}-{phase}       # Phase branch
```

**Feature-only (v3.2):**
```
{feature}                          # Initiative root
{feature}-{audience}               # Audience branch (if used)
{feature}-{audience}-{phase}       # Phase branch (if used)
```

Feature-only naming requires a `features.yaml` registry in the control repo to map feature names to their domain/service. Express track defaults to feature-only naming.

### Merge Flow

```
Phase branch → Audience branch     (phase completion PR)
Audience → Next audience           (promotion PR with gates)
```

### Lazy Branch Creation

Only `{root}` and `{root}-small` are created at init. Higher audience branches are created lazily when a promotion requires them.

## Commands Reference

### Phase Commands

| Command | Phase | Prerequisites |
|---------|-------|--------------|
| `/preplan` | PrePlan | On small audience, track includes preplan |
| `/businessplan` | BusinessPlan | preplan PR merged (if in track) |
| `/techplan` | TechPlan | businessplan PR merged (if in track) |
| `/devproposal` | DevProposal | Promoted to medium, techplan PR merged |
| `/sprintplan` | SprintPlan | Promoted to large, devproposal PR merged |
| `/dev` | Dev | Delegates to implementation agents in target projects |
| `/expressplan` | ExpressPlan | Express track — combined planning in one session (no PRs, no milestone branches) |

### Initiative Commands

| Command | Purpose |
|---------|---------|
| `/create-initiative` | Consolidated initiative creation — choose domain, service, or feature scope |

> **Deprecated aliases:** `/new-domain`, `/new-service`, `/new-feature` are forwarded to `/create-initiative` for backward compatibility.

### Utility Commands

| Command | Purpose |
|---------|---------|
| `/onboard` | Bootstrap control repo — provider auth, governance clone, profile, and TargetProjects auto-clone |
| `/status` | Show all initiatives with phases, audiences, and pending actions |
| `/next` | Recommend the next action based on lifecycle state |
| `/switch` | Checkout a different initiative's branch |
| `/help` | Command reference and module version info |
| `/discover` | Discovery and research workflow |
| `/module-management` | Manage installed BMAD modules |
| `/close` | Formally complete, abandon, or supersede the current initiative |
| `/lens-upgrade` | Migrate control repo to latest lifecycle schema version |
| `/dashboard` | Cross-initiative status overview with Gantt timeline |
| `/retrospective` | Review what worked, what broke, and lessons learned for a completed initiative |
| `/log-problem` | Record an issue or friction point for the active initiative |
| `/move-feature` | Reclassify a feature to a different domain/service |
| `/split-feature` | Split a feature initiative into multiple child initiatives |

### Governance Commands

| Command | Purpose |
|---------|---------|
| `/promote` | Promote current audience to next tier (approval-only mode by default) |
| `/sense` | On-demand cross-initiative overlap detection |
| `/constitution` | Resolve and display constitutional governance for current initiative |

## Authority Domains

| Domain | Location | Write Authority |
|--------|----------|----------------|
| Control Repo | `_bmad-output/lens-work/` | @lens writes initiative artifacts |
| Release Module | `{release_repo_root}/lens.core/_bmad/lens-work/` | Module builder only (read-only at runtime) |
| Copilot Adapter | `.github/` | User only (not modified during initiative work) |
| Governance | `TargetProjects/lens/lens-governance/` | Governance leads only (via governance repo PRs) |

Cross-authority writes are **hard errors**, not warnings.

## Promote Semantics (v3.1)

Promotion defaults to **approval-only** mode:

- **Auto-advance drives the happy path** — when the last phase PR in a tier merges, the initiative automatically advances to the next audience.
- **Explicit `/promote`** is only required for `first-promotion` (small → medium), where human review is intentional.
- **Squash-merge + branch cleanup** — promotion merges use squash-merge and the source milestone branch is deleted after merge. The initiative root branch is preserved.

This removes the ceremony of manually promoting at every tier while keeping human gates where they matter.

## Parallel Phase Execution (v3.1)

Phases without data dependencies may execute concurrently. For example, `preplan` and `businessplan` can run in parallel when neither depends on the other's artifacts.

- Parallel groups are declared in `lifecycle.yaml` under `parallel_phases.groups`.
- Each group lists phases and specifies `requires_no_data_dependency: true`.
- Phase branches are created simultaneously; both PRs must merge before the next sequential phase begins.

## Constitution Governance

### 4-Level Hierarchy

```
org/constitution.md              ← Level 1: universal defaults
{domain}/constitution.md         ← Level 2: domain-specific
{domain}/{service}/constitution.md  ← Level 3: service-specific
{domain}/{service}/{repo}/constitution.md  ← Level 4: repo-specific
```

Resolution uses **additive inheritance** — lower levels add requirements, never remove them.

### Constitution Capabilities (v3.2)

The constitution now controls additional lifecycle behaviors:

| Capability | Description |
|-----------|-------------|
| `gate_collapsing` | Allow merging adjacent gates for small features |
| `parallel_phases` | Allow concurrent phase execution |
| `bypass_gates` | Allow express tracks to skip specific gates |
| `dev_completion_requirements` | Define what constitutes dev-complete |
| `branching_strategy` | Branch model: `pr-per-milestone` (default), `feature-only`, or `trunk-based` |
| `target_repo_branching` | Target repo merge strategy: `pr` (default) or `direct-push` |
| `stakeholder_gate` | Stakeholder approval mode: `informational` (default) or `required` |
| `collapse_gates` | Collapse devproposal→sprintplan gates into a single step |
| `features_registry` | Enable features.yaml tracking for feature mobility |

### Gate Collapsing (v3.2)

For small features, adjacent gates can be merged to reduce ceremony:

- Controlled by the constitution (`collapse_gates: true`)
- When enabled and promoting from devproposal→sprintplan: stakeholder-approval gate is skipped, auto-advances through sprintplan to dev-ready
- The constitution defines which initiative scopes qualify
- Gate requirements are still met — they are combined, not skipped

### Compliance Checks

Constitution compliance is automatically checked at:
- Phase PR creation (informational)
- Promotion PR creation (can be hard gate per constitution)

## Cross-Initiative Sensing

Sensing detects overlapping initiatives at lifecycle gates:

| Overlap Type | Conflict Level |
|-------------|---------------|
| Same feature | 🔴 High |
| Same service | 🟡 Medium |
| Same domain | 🟢 Low |

Sensing runs automatically at `/new-*` (pre-creation) and `/promote` (pre-PR). Available on-demand via `/sense`. Default gate mode is informational; constitution can upgrade to hard gate.

### Content-Aware Sensing (v3.1)

Sensing now includes file-level diff analysis beyond branch-name overlap:

| Analysis | Description |
|----------|-------------|
| File overlap | Detects when branches modify the same files |
| Dependency conflicts | Identifies shared dependency version conflicts |
| API surface conflicts | Flags overlapping API endpoint or contract changes |
| Shared infrastructure | Detects concurrent changes to shared config/infra |

The constitution can upgrade content-aware sensing from informational to a hard gate.

## Artifact Templates (v3.1)

Template starters are provided in `assets/templates/` and are auto-populated when a phase branch is created. Templates provide the required structure (headings, tables, sections) that artifact validation checks.

| Template | Artifact |
|----------|----------|
| `product-brief-template.md` | Product brief |
| `prd-template.md` | PRD |
| `ux-design-template.md` | UX design |
| `architecture-template.md` | Architecture |
| `epics-template.md` | Epics |
| `stories-template.md` | Stories |
| `implementation-readiness-template.md` | Implementation readiness |
| `sprint-status-template.yaml` | Sprint status |

### Per-Artifact Validation (v3.1)

Artifact validation now checks structural requirements per type:

- **Required headings** — each artifact type has mandatory section headings
- **Required tables** — PRD, architecture, and epics must contain tables
- **YAML schema** — sprint-status must validate against expected keys
- **Template diff** — artifacts with <20% change from template trigger a warning

Validation runs at phase PR creation and blocks merge if structural requirements are missing.

## Features Registry (v3.2)

The `features.yaml` file in the control repo root tracks all features and their domain/service assignments:

```yaml
oauth-refactor:
  domain: payments
  service: auth
  created: 2026-03-15
  status: active

login-redesign:
  domain: identity
  service: frontend
  split_from: identity-overhaul
  created: 2026-03-20
  status: active
```

**Purpose:**
- Enables feature-only branch naming by providing domain/service lookup
- Tracks feature mobility (moves and splits via `split_from` field)
- Used by sensing to resolve domain/service for overlap detection
- Auto-populated by `/create-initiative`, `/move-feature`, and `/split-feature`

## Problem Logging (v3.2)

The `/log-problem` command records issues and friction points in a `problems.md` file within the initiative output folder. Each entry includes:

- Severity (`low` / `medium` / `high` / `critical`)
- Title and description
- Timestamp and phase context

Problems are committed with a `[PROBLEM:{severity}]` marker. The `/retrospective` workflow consumes this file as input for post-initiative analysis.
