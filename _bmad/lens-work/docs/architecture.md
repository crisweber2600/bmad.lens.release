# Architecture — LENS Workbench Module (lens-work)

**Generated:** 2026-04-01 | **Scan Level:** Deep | **Module Version:** 3.2.0

---

## 1. Executive Summary

The lens-work module implements a declarative, git-native lifecycle orchestration system for AI-driven initiative management. It follows a **contract-driven architecture** where all lifecycle behavior is derived from a single YAML contract (`lifecycle.yaml`), with no hardcoded semantics anywhere in the module.

The module operates as a **stateless orchestrator**: it reads state exclusively from git primitives (branches, commits, PRs, committed YAML state files), delegates work to specialized AI agents via workflows, and uses PRs as the sole gating mechanism for lifecycle progression.

---

## 2. Design Axioms

| Axiom | Statement | Implementation |
|-------|-----------|----------------|
| A1 | Git is the only source of truth | Initiative state stored in committed `initiative-state.yaml`; no event logs, no shadow databases |
| A2 | PRs are the only gating mechanism | Phase completion = merged PR; audience promotion = merged PR; no side-channel approval |
| A3 | Authority domains must be explicit | 4 authority domains; cross-authority writes are hard errors |
| A4 | Sensing must be automatic at lifecycle gates | Runs at `/new-initiative` and `/promote`; can upgrade to hard gate via constitution |
| A5 | The control repo is an operational workspace | NO executable code outside `scripts/` and `_module-installer/`; all behavior declarative |

---

## 3. Core Architecture Pattern: Contract-Driven Lifecycle

### 3.1 The Lifecycle Contract

`lifecycle.yaml` (schema v3.2) is the single source of truth for all lifecycle behavior. It defines:

- **Fundamental Truths** — 3 non-negotiable design axioms
- **Milestones** — 5 promotion backbone points (techplan → devproposal → sprintplan → dev-ready → dev-complete)
- **Phases** — 6 planning phases (preplan → businessplan → techplan → devproposal → sprintplan + expressplan)
- **Tracks** — 8 predefined lifecycle profiles (full, feature, tech-change, hotfix, hotfix-express, spike, quickdev, express)
- **Audience Tiers** — Progressive review scope (small → medium → large → base)
- **Artifact Validation** — Per-artifact structural validators with constitutional overrides
- **Sensing Configuration** — Scope and content overlap detection thresholds
- **Gate Collapsing** — Constitution-driven `collapse_gates` capability for auto-advancing devproposal → sprintplan

### 3.2 Phase-to-Milestone Mapping

```
Milestone: techplan
  └── Phases: preplan → businessplan → techplan
       Agents: Mary (Analyst) → John (PM) + Sally → Winston (Architect)

Milestone: devproposal
  └── Phase: devproposal
       Agent: John (PM)
       Entry gate: adversarial-review (party mode)

Milestone: sprintplan
  └── Phase: sprintplan
       Agent: Bob (Scrum Master)
       Entry gate: stakeholder-approval

Milestone: dev-ready
  └── No phases (constitution-gated)

Milestone: dev-complete (optional)
  └── No phases (tracks story/epic completion)
```

### 3.3 Branch Topology — Lazy Creation Model

```
{initiative-root}                 ← Created at init (only branch created eagerly)
{initiative-root}-techplan        ← Created at techplan milestone completion
{initiative-root}-devproposal     ← Created at devproposal milestone completion
{initiative-root}-sprintplan      ← Created at sprintplan milestone completion
{initiative-root}-dev-ready       ← Created at dev-ready gate passage
```

**Key insight:** Branch existence is a meaningful lifecycle signal. If `{root}-devproposal` exists, the devproposal phase is definitively complete.

### 3.3.1 Feature-Only Branch Naming (v3.2)

Initiatives may use **feature-only** naming where the branch is just `{feature}` instead of the full `{domain}-{service}-{feature}` DSF pattern. This is enabled when:
- The initiative scope is `feature` and the feature name is unique across the workspace
- The `features.yaml` registry maps the short name back to the full domain/service path

**`features.yaml`** (control-repo root) maps feature names to their domain/service context:
```yaml
features:
  auth:
    domain: foo
    service: bar
    initiative_root: auth
  payments:
    domain: billing
    service: core
    initiative_root: payments
```

Sensing resolves feature-only names via this registry during overlap detection and state derivation.

### 3.4 Promotion Flow

```
Phase branch (e.g., foo-bar-auth-preplan)
    ↓ [auto_advance — within-milestone phase transition]
Next phase (e.g., foo-bar-auth-businessplan)
    ↓ [auto_advance_promote — cross-milestone promotion PR]
Milestone branch (e.g., foo-bar-auth-techplan)
    ↓ [/promote — approval + gate verification]
Next milestone branch (e.g., foo-bar-auth-devproposal)
```

---

## 4. Agent Architecture

### 4.1 Primary Agent: `@lens`

The LENS Workbench agent is the single entry point for all user interaction. It operates as a **phase router** and **lifecycle orchestrator**.

**Dual Representation Pattern:**
- `lens.agent.md` — Runtime source (markdown, human-readable, menu-driven)
- `lens.agent.yaml` — Validator-compatible structured companion (IDE validation)

**Activation Sequence (9 steps):**
1. Load persona from agent file
2. Load `bmadconfig.yaml` immediately (blockers if missing)
3. Remember user's name from config
4. Load `lifecycle.yaml` for phase/audience validity
5. Show greeting with menu items
6. Notify user of `/bmad-help` command availability
7. **STOP and WAIT** for user input (critical: no auto-execution)
8. Parse user input: number → menu item[n], text → case-insensitive match
9. Extract handler attributes and process

### 4.2 Skill Delegation Model

| Skill | Type | Purpose | Operations |
|-------|------|---------|------------|
| `git-state` | Read-only | Derive initiative state from git primitives | current-initiative, current-phase, phase-status, promotion-status |
| `git-orchestration` | Write | Branch creation, commits, pushes, PR management | create-branch, create-milestone-branch, commit-artifacts, update-initiative-state |
| `constitution` | Read-only | Governance resolution and compliance | resolve-constitution, check-compliance, resolve-context (cached) |
| `sensing` | Read-only | Cross-initiative overlap detection | Two-pass (live branches + historical), classify: high/medium/low |
| `checklist` | Read-only | Phase gate validation | evaluate-phase-gate, evaluate-promotion-gate |

---

## 5. Workflow Architecture

### 5.1 Organization: 4 Categories, 35 Workflows

| Category | Count | Purpose |
|----------|-------|---------|
| **Core** | 3 | Infrastructure — phase lifecycle, audience promotion, milestone promotion |
| **Router** | 11 | User-facing phase flows — init, preplan, businessplan, techplan, devproposal, sprintplan, dev, discover, close, expressplan, retrospective |

#### Core Workflow Details

Core workflows are **internal infrastructure** — never invoked directly by users.

| Workflow | Trigger | Purpose |
|----------|---------|--------|
| `phase-lifecycle` | Called by router workflows after phase artifacts are committed | Detect phase completion, create/report phase PR, surface promotion readiness, clean up merged phase branches |
| `audience-promotion` | Called by `/promote` when the next promotion step is an audience tier change | Validate gates (artifact, constitution, sensing), create next-audience branch, open promotion PR |
| `milestone-promotion` | Called by `/promote` when the next promotion step is a milestone boundary | Validate gates (phase, artifact, constitution, sensing), create next-milestone branch, open promotion PR |
| **Utility** | 17 | Operational — onboard, status, next, switch, help, promote, module-management, upgrade, dashboard, log-problem, move-feature, split-feature, approval-status, pause-epic, resume-epic, rollback-phase, profile |
| **Governance** | 4 | Compliance — audit-all, compliance-check, cross-initiative, resolve-constitution |

#### Express Track (v3.2)

The **express** track provides combined planning in a single session — no milestone branches, no PRs, ~5 steps total. Ideal for small features or quick changes where full ceremony is unnecessary. Uses the `/expressplan` command. Gate collapsing via `collapse_gates` constitution capability allows auto-advancing devproposal → sprintplan on this track.

### 5.2 Step-File Pattern

Each workflow follows a consistent decomposed structure:

```
workflow-name/
├── SKILL.md          # Skill definition (purpose, triggers, integration)
├── workflow.md       # Entry point (YAML frontmatter + goal)
├── steps/
│   ├── step-01-{purpose}.md
│   ├── step-02-{purpose}.md
│   └── ...
└── resources/        # Templates, examples, validation schemas
```

### 5.3 Shared Includes

`workflows/includes/preflight.md` — Common preflight checks reused across workflows (context validation, config loading, lifecycle contract resolution).

---

## 6. Authority Domains

| Domain | Location | Owner | Operations |
|--------|----------|-------|------------|
| Domain 1 (Control Repo) | `_bmad-output/lens-work/initiatives/` | `@lens` agent | Write initiative artifacts |
| Domain 2 (Release Module) | `{release_repo_root}/lens.core/_bmad/lens-work/` | Module builder only | Read-only at runtime |
| Domain 3 (Copilot Adapter) | `.github/` | User only | Not modified during initiative work |
| Domain 4 (Governance) | `TargetProjects/lens/lens-governance/` | Governance leads only | Cross-repo PRs |

**Rule:** Cross-authority writes are hard errors, not warnings.

---

## 7. Constitutional Governance (4-Level Hierarchy)

```
lens-governance/constitutions/
├── org/constitution.md              ← Level 1: org-wide defaults
├── {domain}/constitution.md         ← Level 2: domain-specific
├── {domain}/{service}/constitution.md  ← Level 3: service-specific
└── {domain}/{service}/{repo}/constitution.md  ← Level 4: repo-specific
```

**Merge rules (additive inheritance):**
- `required_artifacts` — Union (lower levels add requirements)
- `required_gates` — Union
- `gate_mode` — Lower overrides upper (hard > informational)
- `permitted_tracks` — Intersection (lower levels can only restrict)
- `additional_review_participants` — Union

**Caching:** Two-layer cache (session + file) with branch-aware TTL (alpha: 15min, beta: 1hr, other: daily).

---

## 8. Integration Architecture

### 8.1 Provider Adapter Pattern

Scripts detect the git provider from remote URL and route API calls accordingly:

| Provider | Detection | Auth | PR API |
|----------|-----------|------|--------|
| GitHub | `github.com` in remote URL | `GITHUB_PAT` → `GH_TOKEN` → `profile.yaml` | REST API v3 |
| Azure DevOps | `dev.azure.com` in remote URL | `GH_ENTERPRISE_TOKEN` | REST API |

### 8.2 Governance Repository Integration

- **Access:** Read-only at runtime via sibling clone at `TargetProjects/lens/lens-governance`
- **Note:** Current implementation uses a local clone, NOT a git remote (no `git show governance:path`)
- **Reads:** Constitutional rules, closed initiative artifacts, governance inventory
- **Writes:** Only via governance repo PRs (not via lens-work)

### 8.3 IDE Adapter Integration (VS Code / Copilot)

Generated by `_module-installer/installer.js` at CI/CD time:
- `.github/copilot-instructions.md` — Copilot instructions
- `.github/agents/bmad-agent-lens-work-lens.agent.md` — Thin agent wrapper
- `.github/skills/**/SKILL.md` — Skill path references
- `.github/prompts/lens-work.*.prompt.md` — Prompt stubs

All references are by **PATH** (not duplicated content), updated on module version bump.

### 8.4 Release Pipeline

```
Source (bmad.lens.src)
    ↓ [push to master changing bmad.lens.src/lens.core/_bmad/lens-work/**]
CI/CD Pipeline (promote-to-release.yml)
    ↓ [build → overlay → package → installer.js]
Release (lens.core) alpha branch
    ↓ [auto PR]
Release beta branch
```

---

## 9. State Management

### 9.1 Initiative State (`initiative-state.yaml`)

The committed YAML state file is the single source of truth for runtime initiative state:

```yaml
initiative_root: foo-bar-auth
scope: feature
phase: techplan
phase_status: in-progress
milestone: techplan
track: full
artifacts:
  preplan: { status: complete, committed_at: ... }
  businessplan: { status: complete, committed_at: ... }
```

### 9.2 State Derivation Rules

| Query | Source | Derivation |
|-------|--------|------------|
| Active initiative | `git symbolic-ref HEAD` + state file | Branch name → lookup key → `initiative-state.yaml` |
| Current phase | `initiative-state.yaml` → `phase` | Direct read |
| Phase completion | `initiative-state.yaml` → `artifacts.{phase}` | Artifact existence + phase_status |
| Promotion status | Provider adapter PR query | PR merged = promoted |

---

## 10. Testing Strategy

### 10.1 Contract Tests (4 files)

| Test File | Skill | Test Cases | Format |
|-----------|-------|-----------|--------|
| `branch-parsing.md` | `git-state` | 20+ cases: root extraction, audience detection, phase suffix, edge cases | Table-driven markdown |
| `governance.md` | `constitution` | 4-level hierarchy merge, additive inheritance, language overlay | Specification-based |
| `provider-adapter.md` | `git-orchestration` | PR creation, branch hooks, response parsing | Interface contract |
| `sensing.md` | `sensing` | Live branch conflicts, historical context, overlap classification | Table-driven markdown |

### 10.2 Validation Points

1. **Declarative-only scan** — No forbidden executables outside `scripts/` and `_module-installer/`
2. **Required files** — `lifecycle.yaml`, `module.yaml`, etc. must exist
3. **Manifest validation** — Embedded `.github/` payload has required agents, prompts, skills
4. **Configuration validation** — `module.yaml`, `bmadconfig.yaml` well-formed

---

## 11. Configuration Management

### 11.1 Module Configuration (`module.yaml`)

```yaml
version: 3.2.0
type: standalone
global: false
lifecycle_contract: lifecycle.yaml
dependencies:
  required: [core]
  optional: [cis, tea]
```

### 11.2 Runtime Configuration (`bmadconfig.yaml`)

Template with `{project-root}` variable resolution:
- `target_projects_path` — Where target repos live (default: `../TargetProjects`)
- `default_git_remote` — Provider identifier (default: `github`)
- `lifecycle_contract` — Path to lifecycle.yaml
- `initiative_output_folder` — Initiative artifacts output
- `personal_output_folder` — User-specific workspace files

### 11.3 Install Questions

| Question | Default | Purpose |
|----------|---------|---------|
| `target-projects-path` | `../TargetProjects` | Where to find/create target repos |
| `default-git-remote` | `github` | Git provider selection |
| `ides` | `github-copilot` | IDE adapter targets |

---

## 12. Governance Repository Requirements

Workflows that resolve constitutions or read lifecycle contracts require access to the governance repository. The governance repo is cloned into a configured path during `setup-control-repo` (default: `TargetProjects/lens/lens-governance`).

### 12.1 Governance Access by Workflow

| Workflow | Governance Access | What It Reads |
|----------|-------------------|---------------|
| `/new-initiative` (init-initiative) | Required | Constitution hierarchy for track filtering; sensing overlap data |
| `/promote` (promote-phase) | Required | Constitution for gate validation; artifact validators |
| `/cross-check` (cross-initiative) | Required | Constitution for sensing thresholds; overlap policies |
| `/move-feature` | Optional | Constitution for target domain/service validation |
| `/audit-all` | Required | Full constitution hierarchy for compliance scanning |
| `/sprintplan` | Read-only | Lifecycle contract for phase/track validation |
| `/status` | None | Uses only local git state and initiative-state.yaml |
| `/next` | None | Derives actions from local initiative state |
| `/onboard` | None | Creates local config only |
| `/profile` | None | Reads/writes local bmadconfig.yaml |
| `/approval-status` | Read-only | Lifecycle contract for approval gate definitions |
| `/rollback-phase` | Required | Constitution for rollback permissions |
| `/pause-epic` / `/resume-epic` | None | Updates local initiative-state.yaml only |

### 12.2 Failure Modes

When governance access is required but unavailable:

1. **Clone missing** — Preflight detects missing governance path → directs to `setup-control-repo`
2. **Stale clone** — Constitution may reference outdated rules → preflight warns if governance HEAD is >7 days behind remote
3. **Network offline** — Governance reads from local clone succeed; PR-based operations fail gracefully with retry guidance
