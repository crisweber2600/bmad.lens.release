# LENS Workbench Module — v3.1.0

**Module Code:** `lens-work`
**Type:** Standalone BMAD Module
**Schema Version:** 3.1

## Overview

LENS Workbench v3 provides guided lifecycle routing with git-orchestrated discipline for BMAD workflows. It manages the full planning lifecycle from pre-planning through sprint execution using automated branch topology, PR-based review gates, and constitutional governance.

## Design Principles

- **Git is the only source of truth** — no secondary state stores, no git-ignored runtime state
- **PRs are the only gating mechanism** — automatic PR creation at phase/milestone promotion boundaries
- **Authority domains are explicit** — every file belongs to exactly one domain
- **Sensing is automatic** — cross-initiative awareness at lifecycle gates
- **Declarative only** — no runtime code (JS, Python, etc.)

## Module Structure

```
lens-work/
├── bmadconfig.yaml        # BMAD agent activation config + source defaults
├── lifecycle.yaml         # THE contract — phases, milestones, tracks, branches
├── module.yaml            # Module identity, skills, workflow manifest
├── module-help.csv        # Help entries (13-column format)
├── agents/                # Runtime BMAD agent definitions
├── skills/                # Folder-based skills (each has SKILL.md with frontmatter)
│   ├── checklist/SKILL.md
│   ├── constitution/SKILL.md
│   ├── git-orchestration/SKILL.md
│   ├── git-state/SKILL.md
│   └── sensing/SKILL.md
├── workflows/             # core, router, utility, governance (each has SKILL.md + workflow.md + steps/)
├── prompts/               # User-facing prompt entry points
├── scripts/               # Cross-platform PR creation & PAT management (no gh CLI needed)
├── docs/                  # Human-readable reference documentation
├── bmad-lens-work-setup/  # Legacy setup skill (use _module-installer for CI/CD)
│   ├── SKILL.md
│   ├── scripts/           # merge-config.py, merge-help-csv.py, cleanup-legacy.py
│   └── assets/            # module.yaml, module-help.csv copies
├── _module-installer/     # CI/CD installer — generates IDE adapters for release builds
│   └── installer.js       # Node.js installer (called by promote-to-release.yml)
├── .claude-plugin/        # marketplace.json distribution manifest
└── tests/contracts/       # Slim contract tests
```


## Skills (5)

Skills fall into two archetypes:

- **Internal delegation skills** (`git-state`, `git-orchestration`, `constitution`, `sensing`, `checklist`) — invoked by workflows for specific operations. Not directly user-facing.
- **Workflow skills** (`dashboard`) — thin SKILL.md wrappers that redirect to a workflow. These appear as Copilot skills but execute a full workflow.

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

## Getting Started — New Control Repo

A **control repo** is your local workspace for running LENS Workbench. The setup script bootstraps everything: it clones this release module, copies the IDE adapter, sets up your governance repo, and writes the configuration files that `/onboard` needs.

### Step 1: Create and clone your control repo

```bash
# Create a new repo on GitHub (e.g., myproject.src), then clone it:
git clone https://github.com/your-username/myproject.src.git
cd myproject.src
```

### Step 2: Clone the release module

```bash
# macOS / Linux / Git Bash:
git clone --branch beta https://github.com/your-username/lens.core.git

# Windows PowerShell:
git clone --branch beta https://github.com/your-username/lens.core.git
```

### Step 3: Run the setup script

Run with **no arguments** to enter the interactive wizard:

```bash
# macOS / Linux / Git Bash:
./lens.core/_bmad/lens-work/scripts/setup-control-repo.sh
```

```powershell
# Windows PowerShell:
.\lens.core\_bmad\lens-work\scripts\setup-control-repo.ps1
```

The wizard auto-detects your GitHub username, walks you through each setting with smart defaults, and asks for confirmation before making changes.

> **For CI / scripted use**, pass `--org` (bash) or `-Org` (PowerShell) to skip the wizard:
>
> ```bash
> ./lens.core/_bmad/lens-work/scripts/setup-control-repo.sh --org your-username
> ```

The setup script will:

1. **Pull latest** for `lens.core` (or clone if first run)
2. **Copy `.github/`** from the release module — installs the GitHub Copilot adapter
3. **Clone your governance repo** (auto-creates it as a private repo if `gh` CLI is available)
4. **Create output directories** — `_bmad-output/lens-work/initiatives/` and `personal/`
5. **Write `governance-setup.yaml`** — stores governance repo coordinates for preflight and `/onboard`
6. **Write `LENS_VERSION`** — version compatibility file read by preflight
7. **Update `.gitignore`** — excludes cloned repos and personal data

### Step 4: Store your GitHub PAT

> **Run this in your terminal, not in AI chat.** PATs should never be typed into a chat interface.

```bash
bash lens.core/_bmad/lens-work/scripts/store-github-pat.sh
```

```powershell
.\lens.core\_bmad\lens-work\scripts\store-github-pat.ps1
```

### Step 5: Run `/onboard`

Open VS Code with GitHub Copilot Chat and type:

```
/onboard
```

This validates authentication, creates your profile, and clones target project repos from the governance `repo-inventory.yaml`.

### Step 6 (Optional): Install additional IDE adapters

GitHub Copilot is ready after setup. For other IDEs, run the module installer:

```bash
./lens.core/_bmad/lens-work/scripts/install.sh --ide cursor    # single IDE
./lens.core/_bmad/lens-work/scripts/install.sh --all-ides       # all supported IDEs
```

```powershell
.\lens.core\_bmad\lens-work\scripts\install.ps1 -IDE cursor
.\lens.core\_bmad\lens-work\scripts\install.ps1 -AllIDEs
```

> **Full setup details:** See [`scripts/README.md`](scripts/README.md) for parameter reference, generated file documentation, re-run behavior, and troubleshooting.

---

## Installation (IDE Adapters)

The setup script above handles the initial GitHub Copilot adapter automatically. The commands below are for **adding or updating IDE adapters** after setup.

### Quick Install (default — GitHub Copilot adapter only)

```bash
# From the control repo root:
./lens.core/_bmad/lens-work/scripts/install.sh

# Windows:
powershell .\lens.core\_bmad\lens-work\scripts\install.ps1
```

### Multi-IDE Install

```bash
./lens.core/_bmad/lens-work/scripts/install.sh --all-ides
```

### Update Existing Adapters

```bash
./lens.core/_bmad/lens-work/scripts/install.sh --update
```

See `module.yaml` `install_questions` for configuration options (target projects path, default git provider, IDE selection).

## Quick Start

1. **Install** — run the installer script above
2. **Onboard** — use `/onboard` to bootstrap the control repo (detect provider, validate auth, create profile, auto-clone missing TargetProjects from inventory)
3. **Create initiative** — use `/new-domain`, `/new-service`, or `/new-feature`
4. **Begin planning** — use `/preplan` to start the lifecycle
5. **Check status** — use `/status` at any time to see git-derived state

## Components

### Agent

- `LENS` — lifecycle router and control-plane orchestrator
- Runtime source: `agents/lens.agent.md`
- Structured companion for validation and tooling: `agents/lens.agent.yaml`

### Workflow Sets

- **Core:** `phase-lifecycle`, `milestone-promotion`
- **Router:** `init-initiative`, `preplan`, `businessplan`, `techplan`, `devproposal`, `sprintplan`, `dev`, `discover`
- **Utility:** `onboard`, `status`, `next`, `switch`, `help`, `module-management`
- **Governance:** `compliance-check`, `resolve-constitution`, `cross-initiative`


## Commands

All commands are available via the LENS agent menu. Initiative creation is now consolidated under a single `[NI] Create Initiative` entry (domain, service, or feature). New commands:
- `[CL] Close Initiative` — formally complete, abandon, or supersede the current initiative
- `[UG] Lens Upgrade` — migrate control repo to latest schema version

Menu/command triggers:
`/onboard`, `/create-initiative` (`/new-domain`, `/new-service`, `/new-feature`), `/preplan`, `/businessplan`, `/techplan`, `/devproposal`, `/sprintplan`, `/dev`, `/status`, `/next`, `/switch`, `/promote`, `/sense`, `/constitution`, `/discover`, `/module-management`, `/help`, `/close`, `/lens-upgrade`

## Configuration

Configuration is carried in `bmadconfig.yaml`.

- In source, `bmadconfig.yaml` acts as the template for BMAD agent activation and module defaults.
- In installed control repos, `bmadconfig.yaml` is the runtime materialized config file.

Install-time values are sourced from `module.yaml` install questions:

| Variable | Purpose | Default |
|----------|---------|---------|
| `target-projects-path` | Where repos are cloned | `../TargetProjects` |
| `default-git-remote` | Git provider (GitHub, GitLab, Azure DevOps) | `github` |
| `ides` | IDE adapters to install | `github-copilot` |

The install-question keys use validator-friendly kebab-case. During installation, the module installer maps them into the existing runtime `bmadconfig.yaml` keys `target_projects_path` and `default_git_remote` so agent and workflow compatibility stays intact.


## Documentation

See the [docs/](docs/) folder for detailed reference:

- [Lifecycle Reference](docs/lifecycle-reference.md) — Phases, milestones, tracks
- [Lex Persona](docs/lex-persona.md) — Governance voice used by `@lens`
- [Copilot Adapter Reference](docs/copilot-adapter-reference.md) — Agent stub architecture
- [Copilot Adapter Templates](docs/copilot-adapter-templates.md) — Template patterns
- [Script Integration Summary](docs/script-integration.md) — PAT-based PR and promotion script integration notes
- [Pipeline: Source to Release](docs/pipeline-source-to-release.md) — CI/CD promotion
- [copilot-instructions.md](docs/copilot-instructions.md) — Copilot agent instructions
- [copilot-repo-instructions.md](docs/copilot-repo-instructions.md) — Repo-specific Copilot instructions

## Dependencies

- **Required:** `core` — BMAD core infrastructure (party-mode workflow, shared tasks, base agent definitions)
- **Optional:** `cis` — Creative Innovation Suite (brainstorming, design thinking, storytelling skills used during preplan/expressplan), `tea` — Test Engineering Academy (test framework setup, test design, test automation skills used during devproposal/sprintplan)

## Author

LENS Workbench is part of the BMad Method ecosystem. See the [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD) for more information.



## Known Issues & Next Steps

- Token efficiency: Some workflow prompts and instructions could be compressed for lower token usage.
- Menu categorization: Opportunity to group menu items by lifecycle phase for clarity.
- First-run detection: Logic could be refined for more robust onboarding.
- Sensing workflow: Prompt and step consolidation for efficiency.
- Workflow validation: Deep validation and migration to step-driven execution is planned (see TODO.md).
- Dual agent representation: `.md` runtime source and `.yaml` structured companion pattern to be documented.

See [TODO.md](TODO.md) for the full checklist and next steps.

# Updated: Apr 1, 2026
