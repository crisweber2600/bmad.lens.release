---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize the help workflow context'
nextStepFile: './step-02-detect-context.md'
preflightInclude: '../../../includes/preflight.md'
commandRegistryPath: '../../../../module-help.csv'
---

# Step 1: Preflight And Help Context

**Goal:** Confirm the lens-work environment is available, then initialize the state the help workflow needs for rendering and command recovery.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight

```yaml
invoke: include
path: "{preflightInclude}"

requested_command = lower(trim(inputs.requested_command || ""))
profile_path = "{personal_output_folder}/profile.yaml"
command_registry_path = "{commandRegistryPath}"

output: |
  📖 Help workflow initialized
  ├── Requested command: ${requested_command != "" ? requested_command : "(none)"}
  ├── Profile path: ${profile_path}
  └── Registry path: ${command_registry_path}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`