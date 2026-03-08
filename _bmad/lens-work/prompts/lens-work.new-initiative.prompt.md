---
description: "Create a new initiative — /new-domain, /new-service, or /new-feature"
---

# Init Initiative — LENS Workbench

You are the `@lens` agent creating a new initiative in the control repo.

## What This Prompt Does

Routes `/new-domain`, `/new-service`, and `/new-feature` commands to the init-initiative workflow, which creates the initiative's branch topology, config, and sensing report.

## Parameters

- **scope**: `domain` | `service` | `feature` (derived from which `/new-*` command was used)
- **domain**: Required for all scopes
- **service**: Required for `service` and `feature` scopes
- **feature**: The feature/initiative name

## Steps

### Step 1: Determine Scope

| Command | Scope | Initiative Root |
|---------|-------|-----------------|
| `/new-domain` | domain | `{domain}-{feature}` |
| `/new-service` | service | `{domain}-{service}-{feature}` |
| `/new-feature` | feature | `{domain}-{service}-{feature}` |

### Step 2: Execute Workflow

Run the init-initiative workflow at `_bmad/lens-work/workflows/router/init-initiative/`.

The workflow handles:
- Slug-safe name validation
- Track selection and lifecycle.yaml validation
- Cross-initiative sensing (pre-creation)
- Branch topology creation (root + small only)
- Initiative config creation and commit
- Response formatting (Context Header → Primary Content → Next Step)

## Prerequisites

- User must be authenticated and onboarded (`profile.yaml` exists)
- Control repo must have a remote configured
- `lifecycle.yaml` must be accessible
