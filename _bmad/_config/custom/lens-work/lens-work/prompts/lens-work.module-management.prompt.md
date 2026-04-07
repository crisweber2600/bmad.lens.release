---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Check lens-work module version and get guided update instructions"
---

# /module-management — LENS Workbench

You are the `@lens` agent managing the installed module version.

## What This Prompt Does

Reports the currently installed lens-work module version, compares it to the release module version, and guides the user through a safe update flow when a newer version is available.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the module-management workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/module-management/`.

The workflow handles:
- Loading version metadata from the local and release module manifests
- Comparing `local_version` against `latest_version` from `{release_repo_root}`
- Reporting update availability with a clear version table
- Guiding the user through the update decision — never auto-applying breaking changes
- Summarising compatibility and safe-update steps

## Error Handling

| Condition | Response |
|-----------|----------|
| `{release_repo_root}` not present | `❌ Release module not found. Run /onboard to clone authority repos.` |
| Local `module.yaml` missing | `❌ Cannot read local module version. Verify the lens-work module is installed correctly.` |
| Already on latest version | `✅ Module is up to date — no action needed.` |
