# Development Guide — LENS Workbench Module (lens-work)

**Generated:** 2026-04-01 | **Scan Level:** Deep | **Module Version:** 3.2.0

---

## Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Git | 2.28+ | Branch operations, state derivation, commits |
| Bash | 4+ | Unix script execution (install, create-pr, promote, setup, PAT) |
| PowerShell | 5+ | Windows script execution (equivalent .ps1 scripts) |
| Node.js | 16+ | CI/CD installer only (`_module-installer/installer.js`) |
| curl | any | REST API calls in scripts (GitHub/Azure DevOps) |
| jq | any (optional) | JSON parsing in scripts |
| Python | 3.8+ (optional) | Legacy setup merge utilities (`bmad-lens-work-setup/scripts/`) |

---

## Installation

### Default Installation (GitHub Copilot)

```bash
# From control repo root
bash lens.core/_bmad/lens-work/scripts/install.sh
```

### Multi-IDE Installation

```bash
# Install for specific IDE
bash lens.core/_bmad/lens-work/scripts/install.sh --ide cursor

# Install for all supported IDEs
bash lens.core/_bmad/lens-work/scripts/install.sh --all-ides
```

### Update Existing Installation

```bash
bash lens.core/_bmad/lens-work/scripts/install.sh --update
```

### Dry Run (Preview)

```bash
bash lens.core/_bmad/lens-work/scripts/install.sh --dry-run
```

**Supported IDEs:** `github-copilot` (default), `cursor`, `claude`, `codex`

**What install does:**
1. Creates IDE adapter stubs in `.github/` (or IDE-specific config folder)
2. Generates agent wrapper, skill references, prompt stubs
3. Sets up output directory structure
4. Safe to re-run (skips existing files unless `--update`)

---

## Environment Setup

### 1. GitHub PAT (Required for PR Operations)

**CRITICAL:** Run PAT setup OUTSIDE any AI/LLM context.

```bash
# Unix
bash lens.core/_bmad/lens-work/scripts/store-github-pat.sh

# Windows
powershell lens.core/_bmad/lens-work/scripts/store-github-pat.ps1
```

Sets `GITHUB_PAT`, `GH_TOKEN`, and `GH_ENTERPRISE_TOKEN` in environment + shell profile.

### 2. Control Repo Bootstrap

```bash
# Clone governance and release repos into TargetProjects
bash lens.core/_bmad/lens-work/scripts/setup-control-repo.sh
```

Options: `--org`, `--release-org`, `--release-repo`, `--release-branch`, `--base-url`, `--dry-run`

### 3. Configuration

Edit `bmadconfig.yaml` at the module root:

```yaml
github_username: your-github-username    # Required: set to your GitHub username
target_projects_path: "../TargetProjects" # Where target repos live
default_git_remote: github                # git provider (github or azure-devops)
```

---

## Module Structure for Development

### Key Files to Understand

| File | Purpose | When to Modify |
|------|---------|----------------|
| `lifecycle.yaml` | All lifecycle behavior definition | Adding phases, milestones, tracks, validation rules |
| `module.yaml` | Module metadata and registry | Changing version, adding skills/workflows |
| `module-help.csv` | Command index | Adding or modifying user commands |
| `agents/lens.agent.md` | Agent persona and menu | Changing agent behavior, adding menu items |
| `workflows/includes/preflight.md` | Shared preflight checks | Modifying common validation logic |

### Adding a New Workflow

1. Create folder under appropriate category: `workflows/{core|router|utility|governance}/{name}/`
2. Add `SKILL.md` — Skill definition with purpose, triggers, integration description
3. Add `workflow.md` — Entry point with YAML frontmatter
4. Add `steps/step-01-{purpose}.md`, `step-02-{purpose}.md`, etc.
5. Add `resources/` if needed (templates, schemas)
6. Register in `module.yaml` under `workflows`
7. Add entry to `module-help.csv` if user-facing
8. Add menu item to `agents/lens.agent.md` if user-facing
9. Create prompt file `prompts/lens-work.{name}.prompt.md`

### Adding a New Skill

1. Create folder: `skills/{name}/`
2. Add `SKILL.md` with operations, inputs/outputs, preconditions
3. Register in `module.yaml` under `skills`
4. Reference from workflows that need the skill

### Modifying the Lifecycle Contract

1. Edit `lifecycle.yaml`
2. Bump `schema_version` if structural changes
3. Update `docs/lifecycle-reference.md` to match
4. Update `docs/lifecycle-visual-guide.md` if flow changes
5. Run contract tests in `tests/contracts/`

---

## Scripts Reference

| Script | Purpose | Key Flags |
|--------|---------|-----------|
| `install.sh/.ps1` | Module installer | `--ide`, `--all-ides`, `--update`, `--dry-run` |
| `create-pr.sh/.ps1` | Create PR via REST API | `-s/--source`, `-t/--target`, `-T/--title`, `-b/--body`, `--url-only` |
| `promote-branch.sh/.ps1` | Branch promotion | `-s/--source`, `-t/--target`, `-C/--cleanup`, `--no-pr` |
| `setup-control-repo.sh/.ps1` | Bootstrap repos | `--org`, `--release-branch`, `--dry-run` |
| `store-github-pat.sh/.ps1` | PAT management | (interactive, run outside AI context) |

---

## Testing

### Contract Tests

Located in `tests/contracts/`. These are markdown-based specification files (not automated tests):

```bash
# No test runner — these are reference specifications
# Validate manually against implementations
cat tests/contracts/branch-parsing.md    # 20+ branch name parsing cases
cat tests/contracts/governance.md        # Constitutional merge rules
cat tests/contracts/provider-adapter.md  # PR creation interface
cat tests/contracts/sensing.md           # Overlap detection scenarios
```

### Validation Checklist

1. **Declarative-only scan:** Ensure no executables outside `scripts/` and `_module-installer/`
2. **Required files check:** `lifecycle.yaml`, `module.yaml`, `bmadconfig.yaml` must exist
3. **Manifest validation:** `module.yaml` references all skills, workflows correctly
4. **Help CSV alignment:** `module-help.csv` matches agent menu items
5. **Installer smoke test:** Run `install.sh --dry-run` for all IDEs

### Development TODOs (from TODO.md)

- ☐ Deep validation on representative workflows (router/dev, router/sprintplan)
- ☐ Smoke test installer output for all IDEs
- ☐ Verify module-help.csv command ordering aligned with LENS agent menu
- ☐ Confirm install-question naming consistency
- ☐ Document dual agent pattern (`.md` + `.yaml`)

---

## Build & Release Process

### Source → Release Pipeline

```
bmad.lens.src/lens.core/_bmad/lens-work/    (source)
    ↓ push to master (changes in lens.core/_bmad/lens-work/**)
CI/CD: promote-to-release.yml
    ↓ build → overlay → package
_module-installer/installer.js    (called by pipeline)
    ↓ generate IDE adapter stubs
lens.core (alpha branch)
    ↓ auto PR
lens.core (beta branch)
```

See [pipeline-source-to-release.md](./pipeline-source-to-release.md) for details.

---

## Common Development Tasks

### Onboard to LENS Workbench

```
@lens → /onboard
```

### Create a New Initiative

```
@lens → /new-feature   (or /new-domain, /new-service)
```

### Check Current Status

```
@lens → /status
```

### Promote to Next Milestone

```
@lens → /promote
```

### Run Compliance Check

```
@lens → /constitution
```

### Express Planning (v3.2)

```
@lens → /expressplan
```

### Post-Initiative Retrospective (v3.2)

```
@lens → /retrospective
```

### Log a Problem (v3.2)

```
@lens → /log-problem
```

### Move Feature to Different Domain/Service (v3.2)

```
@lens → /move-feature
```

### Split Feature Into Multiple Initiatives (v3.2)

```
@lens → /split-feature
```
