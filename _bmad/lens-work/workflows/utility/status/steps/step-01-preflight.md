---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize status-reporting state'
nextStepFile: './step-02-scan-initiatives.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Status Context

**Goal:** Verify the control repo is ready, then initialize the status-reporting context from the current branch and the requested detail scope.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Read-only workflow: never modify initiative state, branches, or PRs.
- Use preflight plus git-derived context only; do not invent status from secondary stores.

### 1. Shared Preflight And Context Setup

```yaml
invoke: include
path: "{preflightInclude}"

detail_initiative = inputs.detail_initiative || ""
initiative_state = invoke: git-state.current-initiative
current_branch = initiative_state.branch || invoke_command("git symbolic-ref --short HEAD")
current_initiative_root = initiative_state.initiative_root

output: |
  📊 Status workflow initialized
  ├── Current branch: ${current_branch}
  ├── Current initiative: ${current_initiative_root != null ? current_initiative_root : "(none)"}
  └── Detailed initiative request: ${detail_initiative != "" ? detail_initiative : "(none)"}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`

## SUCCESS CRITERIA

- Shared preflight completed successfully.
- Current branch and current initiative root were derived or explicitly reported as absent.