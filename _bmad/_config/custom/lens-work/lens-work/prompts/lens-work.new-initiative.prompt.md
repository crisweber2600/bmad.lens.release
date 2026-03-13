---
model: Claude Sonnet 4.6 (copilot)
description: "Create a new initiative — /new-domain, /new-service, or /new-feature"
---

# Init Initiative — LENS Workbench

You are the `@lens` agent creating a new initiative in the control repo.

## What This Prompt Does

Routes `/new-domain`, `/new-service`, and `/new-feature` commands to the init-initiative workflow, which creates the initiative's branch topology, config, and sensing report.

## Parameters

- **scope**: `domain` | `service` | `feature` (derived from which `/new-*` command was used)
- **domain**: Domain name (collected for domain scope; from context for service/feature)
- **service**: Service/repo name (collected for service scope; from context for feature scope; not used for domain scope)
- **feature**: The feature/initiative name (collected for feature scope only)
- **track**: Lifecycle track (feature scope only — domain/service scopes do not use track)

## Steps

### Step 0: Run Preflight

Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.

If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Determine Scope and Collect Parameters

| Command | Collection Strategy | Initiative Root |
|---------|---------------------|-----------------|
| `/new-domain` | Collect: domain name (no track — containers only) | `{domain}` |
| `/new-service` | Use context domain, collect: service name (no track — containers only) | `{domain}-{service}` |
| `/new-feature` | Use context domain + service, collect: feature name → track | `{domain}-{service}-{feature}` |

**Each scope creates an initiative root with the appropriate number of segments.** Do NOT collect parameters beyond the scope level.

### Step 2: Execute Workflow

Run the init-initiative workflow at `_bmad/lens-work/workflows/router/init-initiative/`.

The workflow handles:
- Slug-safe name validation
- Track selection and lifecycle.yaml validation (feature scope only — domain/service skip track)
- Cross-initiative sensing (pre-creation)
- Branch topology creation (domain/service: root only; feature: root + small)
- Initiative config creation and commit
- Response formatting (Context Header → Primary Content → Next Step)

## Prerequisites

- User must be authenticated and onboarded (`profile.yaml` exists)
- Control repo must have a remote configured
- `lifecycle.yaml` must be accessible
