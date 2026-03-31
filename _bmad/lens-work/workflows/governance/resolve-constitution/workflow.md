---
name: resolve-constitution
description: Resolve the effective constitution for the active initiative using the governance inheritance chain
agent: "@lens"
trigger: Internal governance workflow used by compliance and promotion flows
category: governance
phase_name: governance
display_name: Resolve Constitution
entryStep: './steps/step-01-preflight.md'
---

# Resolve Constitution Workflow

**Goal:** Resolve the effective initiative constitution from the active initiative context and return it to the calling workflow.

**Your Role:** Operate as a read-only governance helper. Gather only the context needed to resolve constitution inheritance and return the result without side effects.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and resolves the initiative identity.
- Step 2 invokes constitution resolution with the derived domain, service, repo, and language context.
- Step 3 returns the resolved constitution to the caller with a concise summary.

State persists through `initiative_state`, `initiative_config`, `resolution_context`, and `resolved_constitution`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and initiative context
2. `step-02-resolve.md` - Constitution resolution
3. `step-03-render-result.md` - Return summary and resolved constitution
