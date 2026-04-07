# Getting Started with LENS Workbench

## What is LENS?

LENS is an AI-powered planning assistant that turns ideas into implementation-ready stories using git as the workflow engine. It guides you through structured planning phases — from brainstorming through architecture to sprint-ready stories — with configurable governance and automated quality gates.

**No runtime code, no database, no external services** — everything lives in git branches, PRs, and committed artifacts.

---

## 3-Step Quick Start

### Step 1: Set Up Your Control Repo

```bash
# Clone or create your control repo, then run:
./setup-control-repo.sh

# Windows:
powershell .\setup-control-repo.ps1
```

This clones the governance repo and sets up the `TargetProjects/` folder where your code repos will live.

### Step 2: Onboard

Open your AI chat and run:

```
/onboard
```

This detects your git provider, validates authentication (PAT), creates your user profile, and auto-clones any missing target repos from the governance inventory.

### Step 3: Start Your First Feature

```
/new-feature
```

LENS will walk you through naming your feature, selecting a lifecycle track, and creating the initiative branch. Then run the command it recommends (usually `/preplan` or `/expressplan`) to begin planning.

---

## Which Track Should I Use?

| Track | When to Use | Phases | PRs Created |
|-------|------------|--------|-------------|
| **express** | Small features, solo dev, quick turnaround | 1 (expressplan) | 0 |
| **feature** | Known business context, skip research | 4 (businessplan → sprintplan) | 3 |
| **full** | Greenfield, complex, or multi-team | 5 (preplan → sprintplan) | 3 |
| **tech-change** | Infra/tooling, no business case needed | 3 (techplan → sprintplan) | 2-3 |
| **hotfix** | Urgent fix, minimal planning | 1 (techplan) | 1 |
| **quickdev** | Delegate directly to implementation agents | 1 (devproposal) | 1 |
| **spike** | Research only, no implementation | 1 (preplan) | 1 |

> **Not sure?** Start with `express` for small work or `feature` for anything substantial.

---

## Key Commands

| Command | What It Does |
|---------|-------------|
| `/status` | Show current initiative state (derived from git) |
| `/next` | Get a recommendation for what to do next |
| `/help` | List all available commands |
| `/switch` | Switch to a different initiative |
| `/dashboard` | See all active initiatives across domains |
| `/expressplan` | Run the express planning workflow (single-phase, no PRs) |
| `/retrospective` | Run a retrospective on a completed initiative |
| `/log-problem` | Record an issue or friction point for the active initiative |
| `/move-feature` | Reclassify a feature to a different domain/service |
| `/split-feature` | Split a feature initiative into multiple child initiatives |

---

## How LENS Uses Git

LENS uses git as its **only source of truth**:

- **Branches** = initiative state (what exists tells you what's been started)
- **PRs** = review gates (approval at milestone boundaries)
- **Committed files** = planning artifacts (what's been produced)

There are no hidden state files, no databases, no runtime processes. If you can read git, you can read LENS state.

### Branch Model

```
main
└── {feature-name}              ← initiative root (all work happens here)
    ├── {feature-name}-techplan     ← created at first milestone promotion
    ├── {feature-name}-devproposal  ← created at second promotion
    └── {feature-name}-dev-ready    ← execution baseline
```

> Express track uses only `{feature-name}` — no milestone branches, no PRs.

### Feature-Only Branch Naming (v3.2)

Initiatives can use short feature-only branch names (e.g., `auth` instead of `foo-bar-auth`) when the feature name is unique. LENS maps short names to their full domain/service path via `features.yaml` at the control repo root.

### Gate Collapsing (v3.2)

Governance constitutions can enable `collapse_gates` to auto-advance devproposal → sprintplan without a separate PR, reducing ceremony for express and lightweight tracks.

---

## Configuration

LENS reads defaults from `{release_repo_root}/lens.core/_bmad/lens-work/bmadconfig.yaml`:

```yaml
user_name: "Your Name"
communication_language: "english"
output_folder: "_bmad-output"
target_projects_path: "../TargetProjects"
default_git_remote: "github"
```

See [Configuration Examples](./configuration-examples.md) for sample configs for different team sizes and git providers.

---

## Next Steps

- [Onboarding Checklist](./onboarding-checklist.md) — detailed step-by-step with troubleshooting
- [Lifecycle Reference](./lifecycle-reference.md) — deep dive into phases, milestones, and tracks
- [Lifecycle Visual Guide](./lifecycle-visual-guide.md) — Mermaid diagrams of the full lifecycle
- [Configuration Examples](./configuration-examples.md) — sample configs for solo dev, teams, enterprise
