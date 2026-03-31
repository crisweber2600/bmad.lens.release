---
name: 'step-01-preflight'
description: 'Run shared preflight and load local and release module manifests'
nextStepFile: './step-02-compare-report.md'
preflightInclude: '../../../includes/preflight.md'
localModulePath: '../../../../module.yaml'
releaseModulePath: '{project-root}/bmad.lens.release/_bmad/lens-work/module.yaml'
---

# Step 1: Preflight And Version Sources

**Goal:** Confirm the workspace is ready and read the local and release module manifests used for version comparison.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Load Module Versions

```yaml
invoke: include
path: "{preflightInclude}"

local_module = load("{localModulePath}")
release_module = load_if_exists("{releaseModulePath}")

local_version = local_module.version || "unknown"
latest_version = release_module != null ? (release_module.version || "unknown") : null

if local_version == "unknown":
  FAIL("❌ Could not parse the local module version from module.yaml.")

output: |
  📦 Module version sources loaded
  ├── Local: ${local_version}
  └── Release: ${latest_version != null ? latest_version : "unavailable"}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`