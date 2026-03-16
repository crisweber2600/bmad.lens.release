# LENS Workbench Module — v2.0.0

**Module Code:** `lens-work`
**Type:** Standalone BMAD Module
**Schema Version:** 2

## Overview

LENS Workbench v2 provides guided lifecycle routing with git-orchestrated discipline for BMAD workflows. It manages the full planning lifecycle from pre-planning through sprint execution using automated branch topology, PR-based review gates, and constitutional governance.

## v2 Design Principles

- **Git is the only source of truth** — no secondary state stores, no git-ignored runtime state
- **PRs are the only gating mechanism** — automatic PR creation at phase/promotion boundaries
- **Authority domains are explicit** — every file belongs to exactly one domain
- **Sensing is automatic** — cross-initiative awareness at lifecycle gates
- **Declarative only** — no runtime code (JS, Python, etc.)

## Module Structure

```
lens-work/
├── lifecycle.yaml         # THE contract — phases, audiences, tracks, branches
├── module.yaml            # Module identity, skills, workflow manifest
├── module-help.csv        # Help entries for all commands
├── agents/                # @lens agent definition
├── skills/                # git-state, git-orchestration, constitution, sensing, checklist
├── workflows/             # core, router, utility, governance, includes
├── prompts/               # User-facing prompt entry points
├── scripts/               # Cross-platform PR creation & PAT management (no gh CLI needed)
├── docs/                  # Human-readable reference documentation
└── tests/contracts/       # Slim contract tests
```

## Skills (5)

| Skill | Purpose |
|-------|---------|
| `git-state` | Derive initiative state from git primitives (read-only) |
| `git-orchestration` | Branch creation, commits, pushes, PR management, provider adapter (write) |
| `constitution` | Constitutional governance resolution and compliance |
| `sensing` | Cross-initiative overlap detection at lifecycle gates |
| `checklist` | Phase gate checklists with progressive validation |

## Scripts

PR creation and authentication use cross-platform scripts with REST API + PAT. **No `gh` CLI required.**

| Script | Purpose |
|--------|--------|
| `promote-branch.ps1/.sh` | Branch promotion + PR creation via GitHub REST API |
| `store-github-pat.ps1/.sh` | Secure PAT setup into environment variables (run outside AI chat) |

PAT resolution: `GITHUB_PAT` env var → `GH_TOKEN` env var → `profile.yaml` → URL-only fallback

## Installation

### Quick Install (default — GitHub Copilot adapter only)

```bash
# From the control repo root:
./_bmad/lens-work/scripts/install.sh

# Windows:
powershell .\_bmad\lens-work\scripts\install.ps1
```

### Multi-IDE Install

```bash
./_bmad/lens-work/scripts/install.sh --all-ides
```

### Update Existing Adapters

```bash
./_bmad/lens-work/scripts/install.sh --update
```

See `module.yaml` `install_questions` for configuration options (target projects path, default git provider, IDE selection).

## Quick Start

1. **Install** — run the installer script above
2. **Onboard** — use `/onboard` to bootstrap the control repo (detect provider, validate auth, create profile, auto-clone missing TargetProjects from inventory)
3. **Create initiative** — use `/new-domain`, `/new-service`, or `/new-feature`
4. **Begin planning** — use `/preplan` to start the lifecycle
5. **Check status** — use `/status` at any time to see git-derived state

## Commands

`/onboard`, `/new-domain`, `/new-service`, `/new-feature`, `/preplan`, `/businessplan`, `/techplan`, `/devproposal`, `/sprintplan`, `/dev`, `/status`, `/next`, `/switch`, `/promote`, `/sense`, `/help`

## Configuration

Configuration is managed through `module.yaml` install questions:

| Variable | Purpose | Default |
|----------|---------|---------|
| `target_projects_path` | Where repos are cloned | `../TargetProjects` |
| `default_git_remote` | Git provider (GitHub, GitLab, Azure DevOps) | `github` |
| `ides` | IDE adapters to install | `github-copilot` |

## Documentation

See the [docs/](docs/) folder for detailed reference:

- [Lifecycle Reference](docs/lifecycle-reference.md) — Phases, audiences, tracks
- [Copilot Adapter Reference](docs/copilot-adapter-reference.md) — Agent stub architecture
- [Copilot Adapter Templates](docs/copilot-adapter-templates.md) — Template patterns
- [Pipeline: Source to Release](docs/pipeline-source-to-release.md) — CI/CD promotion

## Dependencies

- **Required:** `core` — BMAD core infrastructure
- **Optional:** `cis` — Creative Innovation Suite, `tea` — Test Engineering Academy

## Author

LENS Workbench is part of the BMad Method ecosystem. See the [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD) for more information.


# Updated: Mon, Mar  9, 2026  2:07:59 PM



