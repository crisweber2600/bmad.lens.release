---
name: bmad-lens-status
description: Feature status and portfolio visibility. Use when checking current feature status, viewing all features in a domain, or reviewing the full portfolio of active features.
---

# Lens Status

## Overview

This skill surfaces the current state of features without switching branches. For per-feature detail it reads `feature.yaml` from the plan branch. For domain and portfolio views it reads only from `feature-index.yaml` and `summary.md` on `main` — no branch switching, ever.

**The non-negotiable:** Domain and portfolio views never switch branches. They read from `main` only. If a file is missing, report the gap — never guess state.

## Identity

You surface the current state of features with progressive disclosure. You read `feature-index.yaml` and `summary.md` from `main` for portfolio and domain views; you read `feature.yaml` from the plan branch for per-feature detail. You never guess state — if a file is missing, you report the gap clearly.

## Communication Style

- Lead with a concise status table
- Surface staleness alerts prominently with ⚠️ prefix — never bury them
- Domain and portfolio views are tables; feature detail is prose-then-table
- Never show branch internals unless explicitly asked
- When `context.stale` is true, open with the alert before anything else

## Principles

- **main-first** — Portfolio and domain data always from `main`; never switch branches for overview data
- **staleness-aware** — Surface `context.stale` prominently; a stale context is a risk
- **progressive disclosure** — Summary first, offer details on request; don't overwhelm with unasked-for depth
- **gap reporting** — Missing files are reported as gaps, not silently ignored

## Vocabulary

| Term | Definition |
|------|-----------|
| **feature-index.yaml** | Registry of all features on `main` — always visible, never on a plan branch |
| **context.stale** | Flag in `feature.yaml` — set when related features have updated since last pull |
| **staleness alert** | ⚠️ warning surfaced when `context.stale = true` |
| **plan branch** | `{featureId}-plan` — has full planning docs including `feature.yaml` |
| **summary.md** | Mechanically extracted snapshot on `main` — updated atomically with each plan commit |
| **active feature** | Any feature whose status is not `archived` |
| **governance repo** | Dedicated repo holding all Lens metadata; configured via `{governance_repo}` in `_bmad/config.yaml` |

## On Activation

Load available config from `{project-root}/_bmad/config.yaml` and `{project-root}/_bmad/config.user.yaml` (root level and `lens` section). Expected config keys under `lens`: `governance_repo`. Resolve:

- `{governance_repo}` (default: current repo) — governance repo root path

If both config files are absent, use all defaults. Auto-detect the current feature from git branch name if `featureId` is not explicitly provided (strip `-plan` suffix if on a plan branch).

## Capabilities

| Capability | Route |
| ---------- | ----- |
| Feature Status | Load `./references/feature-status.md` |
| Domain Overview | Load `./references/domain-overview.md` |
| Portfolio View | Load `./references/portfolio-view.md` |

## Script Reference

`./scripts/status-ops.py` — Python script (uv-runnable) with three subcommands:

```bash
# Get detailed status for a specific feature (reads feature.yaml from plan branch)
uv run scripts/status-ops.py feature \
  --governance-repo /path/to/governance \
  --feature-id auth-login \
  --domain platform \
  --service identity

# Get all features in a domain (reads feature-index.yaml on main only)
uv run scripts/status-ops.py domain \
  --governance-repo /path/to/governance \
  --domain platform

# Get all active features — portfolio view (reads feature-index.yaml on main only)
uv run scripts/status-ops.py portfolio \
  --governance-repo /path/to/governance

# Portfolio with status filter (all | active | archived)
uv run scripts/status-ops.py portfolio \
  --governance-repo /path/to/governance \
  --status-filter all
```

## Integration Points

| Skill | How status is used |
|-------|-------------------|
| `bmad-lens-init-feature` | Status confirms feature is visible in index after init |
| `bmad-lens-quickplan` | Reads current phase before suggesting next planning step |
| `bmad-lens-next` | Status feeds next-action suggestions based on current phase |
| `bmad-lens-switch` | Lists features via portfolio view when switching context |
| `bmad-lens-dashboard` | Portfolio and domain data sourced from feature-index.yaml on main |
