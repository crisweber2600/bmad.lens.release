---
name: module-management
description: Check the installed lens-work module version, compare it to release, and guide safe self-service updates
agent: "@lens"
trigger: User-initiated module-management or update command
category: utility
phase_name: utility
display_name: Module Management
entryStep: './steps/step-01-preflight.md'
---

# Module Management Workflow

**Goal:** Report the installed lens-work module version, compare it to the release module version, and guide the user through a safe update flow when a newer version exists.

**Your Role:** Operate as a guided module-maintenance helper. Read version metadata from module manifests, never auto-apply breaking changes, and keep user data outside the update blast radius.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and loads local and release module versions.
- Step 2 compares versions and reports whether an update is available.
- Step 3 handles update confirmation and guidance.
- Step 4 summarizes compatibility checks and closes the workflow.

State persists through `local_module`, `release_module`, `local_version`, `latest_version`, `update_available`, and `update_confirmed`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and module version loading
2. `step-02-compare-report.md` - Version comparison and status report
3. `step-03-update-guidance.md` - Guided update decision and next steps
4. `step-04-compatibility-closeout.md` - Compatibility summary and final result
