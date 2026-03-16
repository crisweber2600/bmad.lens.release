---
applyTo: "**"
---

# Repository Topology — BMAD Control Repo

This workspace is a **BMAD control repo** that orchestrates planning and development across multiple nested repositories. Understanding this topology is critical — every agent, prompt, and workflow must respect these boundaries.

## Three Repository Zones

### 1. Control Repo (workspace root)

The top-level workspace. This is an **operational workspace**, not a code repo. It contains:

- `.github/` — Copilot adapter stubs (agents, skills, prompts) that reference the release module by path
- `_bmad-output/` — All lens-work runtime state (initiative configs, preflight timestamps, personal profile)
- `setup-control-repo.ps1` — Bootstrap script

**Write rules:** Planning phase prompts write artifacts here (under `_bmad-output/lens-work/initiatives/`). The `/dev` prompt writes ONLY state-tracking files here (`_bmad-output/` sprint-status, state).

### 2. Release Repo (`bmad.lens.release/`)

A **git submodule** containing the BMAD framework release payload. This is the **authority** for all module definitions.

- `_bmad/lens-work/` — The lens-work module: lifecycle contract, skills, workflows, prompts, scripts, agents, docs
- `_bmad/bmm/`, `_bmad/core/`, `_bmad/cis/`, etc. — Other BMAD modules
- `_bmad/_config/` — Global manifests (agent, workflow, task, tool, files)

**Write rules:** NEVER modify files in `bmad.lens.release/`. It is read-only reference material. All `_bmad/` path references in prompts and workflows resolve relative to `bmad.lens.release/`, NOT the workspace root.

### 3. TargetProjects

Contains **cloned code repositories** organized by `{domain}/{service}/{repo}`. The base path is configured in `bmad.lens.release/_bmad/lens-work/bmadconfig.yaml` as `target_projects_path` (default: `../TargetProjects`).

Each subfolder is an independent git repo with its own `.git/`, branches, and remotes.

**Write rules:** The `/dev` prompt writes ALL implementation code here — file creation, modification, commits, pushes, and PRs happen exclusively in the target repo resolved from the initiative config.

## Path Resolution Rules

| Reference Pattern | Resolves To |
|---|---|
| `_bmad/lens-work/...` in a prompt or workflow | `bmad.lens.release/_bmad/lens-work/...` |
| `_bmad/_config/...` | `bmad.lens.release/_bmad/_config/...` |
| `_bmad-output/...` | Workspace root `_bmad-output/...` (control repo) |
| `{target_projects_path}/{domain}/{service}/{repo}/` | The cloned code repo for that initiative |
| `.github/prompts/lens-work.*.prompt.md` | Stub files — always follow the redirect to `bmad.lens.release/_bmad/lens-work/prompts/...` |
| `.github/skills/lens-work-*/SKILL.md` | Stub files — always follow the redirect to `bmad.lens.release/_bmad/lens-work/skills/...` |

## The `/dev` Prompt — Strict Write Scope

When `lens-work.dev.prompt.md` is executed:

1. **Implementation code** (new files, edits, commits, branches, PRs) goes ONLY in the target repo under the configured `target_projects_path`
2. **State tracking** (sprint-status, initiative state) goes ONLY in `_bmad-output/`
3. **NEVER modify** the control repo root, `.github/`, `bmad.lens.release/`, or any other repo

This is enforced by the dev workflow's "Write Scope — Target Repo Only" rule: before implementing any task, verify the working directory is inside the target repo. If verification fails, implementation is blocked.

## Lens-Work Lifecycle Summary

The lens-work module manages a 5-phase planning lifecycle with audience-based promotion gates:

| Phase | Agent | Audience |
|---|---|---|
| PrePlan | Mary (Analyst) | small |
| BusinessPlan | John (PM) | small |
| TechPlan | Winston (Architect) | small |
| DevProposal | John (PM) | small (branches from medium) |
| SprintPlan | Bob (Scrum Master) | small (branches from large) |

- **Dev** is NOT a lifecycle phase — it is a delegation command that hands off to implementation agents in target projects
- Promotions (small → medium → large → base) are independent review gates, not phase assignments
- Git is the only source of truth — branch existence, PR metadata, and committed artifacts determine state
- PRs are the only gating mechanism — no side-channel approvals

## Key Conventions

- All `.github/prompts/` and `.github/skills/` files are **stubs** that redirect to full implementations in `bmad.lens.release/`
- Never duplicate module content into `.github/` — module updates propagate through path references
- The `bmad.lens.release/` submodule branch matters: on `alpha`, run full preflight at most once per hour; on `beta`, run full preflight at most once every 3 hours
- Initiative artifacts live at `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`
