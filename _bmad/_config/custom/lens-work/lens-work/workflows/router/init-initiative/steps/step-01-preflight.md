---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize scope for initiative creation'
nextStepFile: './step-02-collect-scope.md'
preflightInclude: '../../../includes/preflight.md'
lifecycleContract: '../../../../lifecycle.yaml'
moduleConfigPath: '../../../../bmadconfig.yaml'
---

# Step 1: Preflight And Scope Initialization

**Goal:** Confirm the environment is ready, determine which creation command the user invoked, and initialize the shared state for the rest of the workflow.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Scope Detection

```yaml
invoke: include
path: "{preflightInclude}"
params:
  skip_constitution: true

command_name = inputs.command_name

if command_name == "/new-domain":
  scope = "domain"
else if command_name == "/new-service":
  scope = "service"
else if command_name == "/new-feature":
  scope = "feature"
else:
  FAIL("❌ Unsupported command for init-initiative: ${command_name}")

lifecycle = load("{lifecycleContract}")
module_config = load("{moduleConfigPath}")
profile = load_if_exists("{personal_output_folder}/profile.yaml")
current_context = invoke: git-state.current-initiative

output: |
  🌱 Initiative creation initialized
  ├── Command: ${command_name}
  └── Scope: ${scope}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`