# Workflow: Module Management

**Module:** lens-work
**Type:** Utility workflow
**Trigger:** Suggested by `/help` version info or user-initiated

---

## Purpose

Combined workflow for module version checking and self-service updates. Reports the currently installed lens-work module version, checks for available updates, and guides the user through updating when a newer version is available.

## Preflight Gate

Run preflight before executing this workflow:

1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

## Part 1: Version Check

### Step 1: Read Local Version

1. Read `module.yaml` from the installed module path (`_bmad/lens-work/module.yaml`)
2. Parse the `version` field
3. Store as `local_version`

### Step 2: Check Remote Version

1. Attempt to read the latest version from `bmad.lens.release` repo
2. Methods (in order of preference):
   a. Check git tags matching semver pattern on the release remote
   b. Read `module.yaml` from the default branch of `bmad.lens.release` via `git show` or remote read
3. Store as `latest_version`
4. If remote is unavailable: report local version only with note about remote check failure

### Step 3: Compare and Report

**Update available:**
```
📦 Module: lens-work v{local_version}
⚠️ Update available: {local_version} → {latest_version}
   Run the module update flow to upgrade.
```

**Up to date:**
```
📦 Module: lens-work v{local_version}
✅ Module is up to date
```

**Remote check failed:**
```
📦 Module: lens-work v{local_version}
⚠️ Could not check for updates — release repo not accessible
```

### Integration with /help

The version check output is appended to the `/help` command response at the bottom, under a "Module Info" section.

---

## Part 2: Self-Service Update

**Key principle:** This is a GUIDED flow — @lens provides steps, user confirms actions. @lens does NOT auto-apply potentially breaking changes.

### Prerequisites

- A newer module version is available (confirmed by version check above)
- User has access to `bmad.lens.release` repo

### Step 4: Confirm Update

```
📦 Module Update Available

Current: v{local_version}
Latest:  v{latest_version}

Proceed with update? (y/n)
```

### Step 5: Guide User to Pull Latest Release

```
To update, pull the latest release module content:

1. Navigate to your control repo
2. Copy the updated module files from bmad.lens.release:
   - Source: bmad.lens.release/_bmad/lens-work/
   - Destination: {control_repo}/_bmad/lens-work/

⚠️ This will overwrite module files only — your initiative data is preserved.
```

### Step 6: Diff and Report Changes

After user confirms the files are updated:

1. Compare old and new module files
2. Categorize changes:
   - **New skills:** Skills added in the new version
   - **Modified workflows:** Workflows with changed content
   - **Removed files:** Files no longer in the module
   - **Config changes:** Changes to module.yaml, lifecycle.yaml, module-help.csv
3. Report changes with impact assessment

```
📋 Change Report (v{old} → v{new}):

New:
  + skills/new-skill.md

Modified:
  ~ skills/sensing.md (added language overlay support)
  ~ lifecycle.yaml (added new track type)

Removed:
  - workflows/deprecated/old-workflow.md

Config:
  ~ module.yaml (version bump, new skill registered)
```

### Step 7: Compatibility Verification

Check control repo structure against new module expectations:

1. Verify required directories exist
2. Identify any breaking changes (renamed skills, changed workflow paths)
3. Report compatibility issues

```
✅ Compatibility check passed — no breaking changes detected.
```

### Step 8: Confirm Complete

```
✅ Module updated to v{latest_version}
   All compatibility checks passed.
   Your initiative data is unchanged.
```

## Error Handling

| Error | Response |
|-------|----------|
| Local module.yaml not found | `❌ Module not installed. Run /onboard to set up.` |
| Remote not accessible | Show local version with remote check warning |
| Version parse error | `⚠️ Could not parse module version. Check module.yaml format.` |
| Already up to date | `✅ Module is already at latest version.` |

## Key Constraints

- Version from `module.yaml` is the single source of truth
- Remote check uses git tags from `bmad.lens.release` (semver tags)
- Graceful degradation when remote is unavailable
- GUIDED flow — user confirms actions, @lens does not auto-apply
