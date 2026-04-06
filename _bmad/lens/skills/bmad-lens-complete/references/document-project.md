# Document Project

Capture the final state of the implemented feature before archiving.

## Outcome

Project documentation files are written to the feature directory capturing the delivered state: what was built, how it works, how to deploy it, and where it lives in the codebase.

## When to Use

After the retrospective and before finalize. This is the **non-negotiable** step — the final implemented state must be captured before the feature is archived.

## What to Capture

At minimum, the following must exist in the feature directory before archiving:

| File | Purpose |
|------|---------|
| `docs/README.md` | What was built, why, and how to use it |
| `docs/deployment.md` | How to deploy, env vars, dependencies, rollback notes |

Additional documentation (optional but encouraged):

| File | Purpose |
|------|---------|
| `docs/api.md` | API endpoints, contracts, request/response examples |
| `docs/architecture.md` | Key design decisions, diagrams, tradeoffs |
| `docs/runbook.md` | Operational procedures for the feature |

## Process

1. Review the feature's target repositories and implemented changes
2. Confirm the core documentation exists or prompt user to create it
3. If documentation is missing, generate stubs from the feature.yaml context:

```bash
# Read feature context
python3 {skill-dir}/scripts/../../../bmad-lens-feature-yaml/scripts/feature-yaml-ops.py read \
  --governance-repo {governance_repo} \
  --feature-id {featureId}
```

4. For each missing required doc, ask the user to provide content or auto-generate a populated stub
5. Write docs to `{feature-dir}/docs/`

## Minimum README Template

```markdown
# {feature name}

**Feature ID:** {featureId}
**Domain:** {domain} / {service}
**Delivered:** {ISO date}

## Overview

{What was built and why}

## How It Works

{Key implementation details}

## Configuration

{Environment variables, feature flags, config keys}

## Usage

{How to use this feature — endpoints, UI flows, CLI commands}

## Known Limitations

{Any constraints or known issues at delivery time}
```

## Confirmation

After documentation is captured, confirm:

```
✓ docs/README.md written to {feature-dir}/docs/README.md
✓ docs/deployment.md written to {feature-dir}/docs/deployment.md
```

If the user wants to skip optional docs, that is acceptable. Required docs (README.md) must exist.
