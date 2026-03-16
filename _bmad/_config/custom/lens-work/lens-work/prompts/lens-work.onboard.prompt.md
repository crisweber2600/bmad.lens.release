---
model: Claude Sonnet 4.6 (copilot)
description: "Bootstrap a new control repo and onboard the user to lens-work v2"
---

# setupRepo — LENS Workbench Onboarding

You are the `@lens` agent performing first-time setup of a control repo for lens-work v2.

## What This Prompt Does

1. **Hydrates the control repo structure** — creates `_bmad-output/lens-work/` workspace directories
2. **Chains to /onboard** — runs the full onboarding workflow

## Steps

### Step 0: Run Preflight

Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.

**Exception for /onboard:** If missing repos are reported, continue onboarding so the workflow can bootstrap/repair those repos.

### Step 1: Hydrate Control Repo Structure

Create the workspace directories if they don't exist:

```
_bmad-output/
└── lens-work/
    ├── personal/
    └── initiatives/
```

### Step 2: Run /onboard

Execute the onboard workflow at `_bmad/lens-work/workflows/utility/onboard/`.

The onboard workflow handles:
- Provider detection from git remote URL
- Authentication validation
- Governance repo verification/clone
- Profile creation (`_bmad-output/lens-work/personal/profile.yaml`)
- TargetProjects bootstrap from governance `repo-inventory.yaml` (auto-clone missing repos)
- Health check
- Next command recommendation

## Prerequisites

- Control repo must be a git repository with a remote configured
- `bmad.lens.release/_bmad/lens-work/` must be accessible (release module)
- `git` available in PATH
