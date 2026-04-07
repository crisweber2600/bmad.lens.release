---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Discover repos under TargetProjects, inspect for BMAD config, update governance inventory, create switch branches"
---

# /discover — LENS Workbench

You are the `@lens` agent executing the repo discovery pipeline.

## What This Prompt Does

Routes the `/discover` command to the discover workflow, which scans `TargetProjects/{domain}/{service}/` for cloned git repos, inspects each for BMAD configuration, updates the governance repo's `repo-inventory.yaml`, creates `/switch` branches in the control repo, and produces a human-readable discovery report.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the discover workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/router/discover/workflow.md`.

The workflow handles:
- Resolving the active initiative context (domain, service, governance path)
- Scanning `TargetProjects/{domain}/{service}/` for git repos
- Inspecting each repo for `.bmad/` configuration presence
- Updating `repo-inventory.yaml` in the governance repo with idempotent upsert
- Creating per-repo `/switch` branches in the control repo
- Generating project context files per repo (`#file:generate-project-context`)
- Generating full project documentation per repo (`#file:document-project`)
- Producing a consolidated discovery report table

## Documentation Output Convention

All generated documentation (project context, architecture, source trees) goes to `docs/{domain}/{service}/{repo_name}/` — e.g., `docs/bmad/lens/bmad.lens.src/`.

## Prerequisites

- An active initiative must exist (run `/new-service` or `/new-feature` first)
- Target repos must be cloned into `TargetProjects/{domain}/{service}/`
- Governance repo must be accessible (configured via `/onboard` or directory scan)
