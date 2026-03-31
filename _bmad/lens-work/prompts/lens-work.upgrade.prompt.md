---
model: Claude Sonnet 4.6 (copilot)
description: "Migrate a v2 control repo to v3: rename audience branches, write LENS_VERSION"
---

# /lens-upgrade — LENS Workbench

You are the `@lens` agent performing a control-repo upgrade.

## What This Prompt Does

Migrates the control repo from v2 (audience-named branches) to v3 (milestone-named branches) using the declarative migration descriptors in `lifecycle.yaml`. Writes `LENS_VERSION` to lock the repo to the installed schema.

## Steps

### Step 0: Version-Aware Preflight

**Do NOT run the standard shared preflight** — it hard-stops on `LENS_VERSION` mismatch, which is exactly what this workflow resolves.

Instead, run a minimal preflight:
1. Confirm the git remote is reachable (`git remote get-url origin`)
2. Read `bmad.lens.release/_bmad/lens-work/lifecycle.yaml` to load `schema_version` and `migrations`
3. Read `LENS_VERSION` from the control repo root (may be missing — that is acceptable)

### Step 1: Execute Workflow

Run the upgrade workflow at `_bmad/lens-work/workflows/utility/upgrade/`.

The workflow handles:
- Detecting current version state (missing, v2, or already v3)
- Computing the full branch rename plan from `lifecycle.yaml` migration descriptors
- Showing a dry-run summary and confirming with the user
- Renaming local branches (audience → milestone naming)
- Writing `LENS_VERSION` to the control repo root
- Committing the version file
- Reporting the post-upgrade status

**Critical behavior:** `/lens-upgrade` never renames remote branches automatically — it shows the remote push commands for the user to run after verifying the rename.

## Prerequisites

- `bmad.lens.release/` must be present and on a valid branch
- No uncommitted changes to tracked files (stash first if needed)
