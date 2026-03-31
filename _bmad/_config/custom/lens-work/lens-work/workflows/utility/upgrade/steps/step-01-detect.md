---
name: 'step-01-detect'
description: 'Detect LENS_VERSION, load lifecycle migration descriptors, determine upgrade path, parse --dry-run flag'
nextStepFile: './step-02-plan-renames.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Version Detection

**Goal:** Parse command flags, read the current `LENS_VERSION`, load the `lifecycle.yaml` migration descriptors, decide whether an upgrade is needed, and identify the applicable migration path.

---

## EXECUTION SEQUENCE

### 0. Parse Flags

```yaml
# Parse --dry-run flag from invocation arguments
dry_run = args.includes("--dry-run")
```

### 1. Read Current Version And Target

```yaml
lifecycle_header = load("{lifecycleContract}")
target_version = str(lifecycle_header.schema_version)
# e.g., "3"

# Read LENS_VERSION — missing file is version "missing"
detected_version = file_exists("LENS_VERSION") ? read_file("LENS_VERSION").trim() : "missing"
# e.g., "missing", "2", "2.0.0", "3", "3.0.0"

# Normalize to major integer for comparison
detected_major = detected_version == "missing" ? null : parseInt(detected_version.split(".")[0])
target_major = parseInt(target_version)

# Check if already at target
if detected_major != null and detected_major >= target_major:
  output: "Already at current version (LENS_VERSION: ${detected_version}, module schema: ${target_version})"
  STOP
```

### 2. Load Migration Descriptors

```yaml
lifecycle = load("{lifecycleContract}")
migrations = lifecycle.migrations || []

# Find migration path (start from detected_major, or from 2 if missing/unknown)
from_version = detected_major || 2
applicable_migrations = filter(migrations, m => m.from_version == from_version and m.to_version == target_major)

if applicable_migrations.length == 0:
  output: |
    ⚠️  No migration descriptor found for v${from_version} → v${target_major}.
    Check lifecycle.yaml migrations section.
    Writing LENS_VERSION only (no branch renames will be performed).
  migration = null
else:
  migration = applicable_migrations[0]

output: |
  🔍 Upgrade needed
  ├── Current version: ${detected_version}
  ├── Target version: ${target_version}
  └── Branch rename required: ${migration?.branch_rename_required ?? false}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
