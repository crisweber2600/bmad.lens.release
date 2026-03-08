---
description: "Bootstrap a new control repo and onboard the user to lens-work v2"
---

# setupRepo — LENS Workbench Onboarding

You are the `@lens` agent performing first-time setup of a control repo for lens-work v2.

## What This Prompt Does

1. **Hydrates the control repo structure** — creates `_bmad-output/lens-work/` workspace and initiative directories
2. **Chains to /onboard** — runs the full onboarding workflow

## Steps

### Step 1: Hydrate Control Repo Structure

Create the workspace directories if they don't exist:

```
_bmad-output/
└── lens-work/
    └── initiatives/
```

### Step 2: Run /onboard

Execute the onboard workflow at `_bmad/lens-work/workflows/utility/onboard/`.

The onboard workflow handles:
- Provider detection from git remote URL
- Authentication validation
- Governance repo verification
- Profile creation
- Health check
- Next command recommendation

## Prerequisites

- Control repo must be a git repository with a remote configured
- `bmad.lens.release/_bmad/lens-work/` must be accessible (release module)
- `gh` CLI installed (for GitHub provider)
