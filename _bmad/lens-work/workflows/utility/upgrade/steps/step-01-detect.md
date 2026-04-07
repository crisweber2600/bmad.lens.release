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

# Parse --from and --to version overrides
from_override = parse_flag(args, "--from")   # e.g., "3.2" or null
to_override = parse_flag(args, "--to")       # e.g., "3.3" or null
```

### 1. Read Current Version And Target

```yaml
lifecycle_header = load("{lifecycleContract}")
target_version = to_override || str(lifecycle_header.schema_version)
# e.g., "3.3"

# Read LENS_VERSION — missing file is version "missing"
detected_version = from_override || (file_exists("LENS_VERSION") ? read_file("LENS_VERSION").trim() : "missing")
# e.g., "missing", "2", "3.0.0", "3.2", "3.2.0.0"

# Parse version with minor support: "3.2.0" → 3.2, "3" → 3.0, "missing" → null
detected_numeric = detected_version == "missing" ? null : parseFloat(detected_version)
target_numeric = parseFloat(target_version)
# e.g., detected_numeric = 3.2, target_numeric = 3.3

# Check if already at target
if detected_numeric != null and detected_numeric >= target_numeric:
  output: "Already at current version (LENS_VERSION: ${detected_version}, module schema: ${target_version})"
  STOP
```

### 2. Load Migration Descriptors

```yaml
lifecycle = load("{lifecycleContract}")
migrations = lifecycle.migrations || []

# Find migration path using numeric version comparison
# Supports minor versions: 3.2 → 3.3, not just major: 2 → 3
from_version = detected_numeric || 2
applicable_migrations = filter(migrations, m => parseFloat(str(m.from_version)) == from_version and parseFloat(str(m.to_version)) == target_numeric)

if applicable_migrations.length == 0:
  output: |
    ⚠️  No migration descriptor found for v${from_version} → v${target_numeric}.
    Check lifecycle.yaml migrations section.
    Writing LENS_VERSION only (no branch renames will be performed).
  migration = null
else:
  migration = applicable_migrations[0]

output: |
  🔍 Upgrade needed
  ├── Current version: ${detected_version}
  ├── Target version: ${target_version}
  ├── Branch rename required: ${migration?.branch_rename_required ?? false}
  └── Optional migrations: ${migration?.optional_migrations?.length ?? 0}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
