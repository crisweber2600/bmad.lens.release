---
name: 'step-01-preflight'
description: 'Run preflight and resolve the initiative context needed for constitution inheritance'
nextStepFile: './step-02-resolve.md'
preflightInclude: '../../includes/preflight.md'
---

# Step 1: Preflight And Initiative Context

**Goal:** Confirm the active branch belongs to an initiative and derive the governance identity used for constitution resolution.

---

## EXECUTION SEQUENCE

### 1. Run Preflight And Derive Resolution Context

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
initiative_config = load(initiative_state.config_path)

resolution_context =
  domain: initiative_config.docs.domain || initiative_state.domain
  service: initiative_config.docs.service || initiative_state.service
  repo: initiative_config.docs.repo || initiative_state.repo || ""
  language: initiative_config.language || initiative_config.primary_language || ""
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`