---
name: upgrade
description: Migrate a v2 control repo to v3 — rename audience branches to milestone branches and write LENS_VERSION
agent: "@lens"
trigger: /lens-upgrade command
category: utility
phase_name: utility
display_name: Lens Upgrade
entryStep: './steps/step-01-detect.md'
---

# /lens-upgrade — Migrate Control Repo to v3

**Goal:** Detect the current LENS schema version, compute a full migration plan from `lifecycle.yaml` migration descriptors (branch renames, YAML field renames, initiative-state.yaml creation), confirm with the user (or display as dry-run), apply changes, write `LENS_VERSION`, and commit.

**Your Role:** Operate as a safe, confirmed migration helper. Show every change before applying it. Never auto-rename remote branches — output the push commands instead.

**Flags:**
- `--dry-run` — Display the complete change plan without applying any changes. No branches renamed, no files modified, no commits created.
- `--from N` — Override detected source version (default: auto-detect from LENS_VERSION)
- `--to M` — Override target version (default: lifecycle.yaml schema_version)

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 detects the current version state and loads migration descriptors.
- Step 2 scans local branches, computes the rename plan, identifies YAML field changes, and lists initiative-state.yaml files to create.
- Step 3 presents the full plan, handles `--dry-run` display or confirms with the user, and applies all changes.
- Step 4 writes `LENS_VERSION`, commits with `[LENS:UPGRADE]` marker, and reports completion.

State persists through `detected_version`, `target_version`, `migration`, `branch_scan`, `rename_plan`, `phase_branch_notes`, `yaml_changes`, `init_state_plan`, `renames_applied`, and `dry_run`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-detect.md` — Version detection and migration descriptor load
2. `step-02-plan-renames.md` — Branch scan and rename plan computation
3. `step-03-confirm-and-apply.md` — Display plan, confirm, apply local renames
4. `step-04-write-version.md` — Write LENS_VERSION, commit, report
