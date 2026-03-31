---
name: 'step-01-preflight'
description: 'Run shared preflight and capture the requested switch target'
nextStepFile: './step-02-resolve-target.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Requested Target

**Goal:** Confirm the control repo is ready for a branch switch and capture the optional initiative target from the command input.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight And Argument Capture

```yaml
invoke: include
path: "{preflightInclude}"

target_root = inputs.target_root || ""
current_branch = invoke_command("git symbolic-ref --short HEAD")

output: |
  🔀 Switch workflow initialized
  ├── Current branch: ${current_branch}
  └── Requested target: ${target_root != "" ? target_root : "(prompt required)"}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`