# LENS Workbench — Onboarding Checklist

A step-by-step guide from zero to your first running initiative. Each section builds on the previous one.

---

## Prerequisites

- [ ] **Git** installed and configured (`git config user.name` and `git config user.email` set)
- [ ] **VS Code** (or Cursor/Claude Code) with GitHub Copilot extension
- [ ] **GitHub account** with access to your organization's governance and target repos
- [ ] **Personal Access Token (PAT)** with `repo` scope — [Create one here](https://github.com/settings/tokens)

> **Troubleshooting:** If you don't have access to the governance repo, ask your team lead. LENS won't work without governance access for constitutional governance checks.

---

## Phase 1: PAT Setup

- [ ] Run the PAT storage script (do this **outside** of AI chat — terminal only):

```bash
# macOS/Linux:
./{release_repo_root}/lens.core/_bmad/lens-work/scripts/store-github-pat.sh

# Windows:
powershell .\{release_repo_root}\lens.core\_bmad\lens-work\scripts\store-github-pat.ps1
```

- [ ] Verify PAT is stored: the script will confirm `GITHUB_PAT` or `GH_TOKEN` is set

> **Troubleshooting:**
> - "Permission denied" → Make the script executable: `chmod +x scripts/store-github-pat.sh`
> - PAT not persisting across terminals → Add `export GITHUB_PAT=...` to your shell profile (`.bashrc`, `.zshrc`, or PowerShell `$PROFILE`)
> - PAT resolution order: `GITHUB_PAT` env var → `GH_TOKEN` env var → `profile.yaml` → URL-only fallback

---

## Phase 2: Control Repo Bootstrap

- [ ] Clone or create your control repo
- [ ] Run the setup script:

```bash
./setup-control-repo.sh

# Windows:
powershell .\setup-control-repo.ps1
```

- [ ] Verify the output:
  - `TargetProjects/` folder exists with your code repos cloned
  - `{release_repo_root}/lens.core/_bmad/lens-work/` folder contains the module files
  - No error messages in the script output

> **Troubleshooting:**
> - "Governance repo not found" → Check that the governance repo URL is correct in the setup config
> - "Authentication failed" → Verify your PAT has `repo` scope and is not expired
> - Clone failures → Try cloning the target repo manually first to rule out network/permission issues

---

## Phase 3: Onboard in AI Chat

- [ ] Open VS Code and start a GitHub Copilot chat session
- [ ] Run:

```
/onboard
```

- [ ] The onboard workflow will:
  - Detect your git provider (GitHub, GitLab, Azure DevOps)
  - Validate your PAT authentication
  - Create your user profile at `_bmad-output/lens-work/personal/profile.yaml`
  - Auto-clone any missing TargetProjects repos from the governance inventory
- [ ] Verify: `profile.yaml` exists and contains your username and provider

> **Troubleshooting:**
> - "No governance repo found" → Run `setup-control-repo.sh` first (Phase 2)
> - "PAT validation failed" → Re-run `store-github-pat.sh` (Phase 1)
> - "TargetProjects path not found" → Check `bmadconfig.yaml` has the correct `target_projects_path`

---

## Phase 4: Your First Initiative

- [ ] Create a new feature initiative:

```
/new-feature
```

- [ ] LENS will ask you:
  - **Feature name** — short, descriptive (e.g., `user-auth`, `dark-mode`)
  - **Domain** — which business area (e.g., `payments`, `frontend`)
  - **Service** — which service within the domain (e.g., `api`, `web`)
  - **Track** — lifecycle profile (pick `express` for your first time)
- [ ] Verify: An initiative branch exists in git and `initiative.yaml` is committed

---

## Phase 5: Run Your First Planning Workflow

- [ ] For **express** track, run:

```
/expressplan
```

- [ ] For **feature** or **full** track, run:

```
/preplan
```

- [ ] The workflow will guide you through producing planning artifacts (product brief, PRD, architecture, etc.)
- [ ] Check your progress anytime with `/status`

---

## Normal Day Workflow

Once onboarded, your daily flow is:

```mermaid
flowchart TD
    A[Open VS Code + Copilot Chat] --> B{Have active initiative?}
    B -->|Yes| C[/status — check current state]
    B -->|No| D[/new-feature — start something new]
    C --> E[/next — get recommended action]
    E --> F[Run the recommended phase command]
    F --> G{Phase complete?}
    G -->|Yes| H[/promote — advance milestone]
    G -->|No| F
    H --> I{All phases done?}
    I -->|Yes| J[/dev — delegate to implementation]
    I -->|No| E
    J --> K[/retrospective — review what happened]
    K --> L[/close — formally end initiative]
```

### Quick Reference

| Situation | Command |
|-----------|---------|
| Start of day | `/status` or `/dashboard` |
| Don't know what's next | `/next` |
| Switch to different work | `/switch` |
| Something broke | `/log-problem` |
| Feature is done | `/close --completed` |
| Feature was cancelled | `/close --abandoned` |
| Need help | `/help` |

---

## Glossary

| Term | Meaning |
|------|---------|
| **Control repo** | The repo where LENS lives — contains planning artifacts, not code |
| **Target repo** | A code repo under `TargetProjects/` where implementation happens |
| **Initiative** | A unit of work tracked by LENS (feature, tech change, spike, etc.) |
| **Track** | A lifecycle profile that determines which phases to run |
| **Phase** | A planning stage (preplan, businessplan, techplan, devproposal, sprintplan) |
| **Milestone** | A promotion boundary between phases (approved via PR) |
| **Constitution** | Governance rules that apply at org, domain, service, or repo level |
| **Sensing** | Automatic detection of overlap between initiatives |
