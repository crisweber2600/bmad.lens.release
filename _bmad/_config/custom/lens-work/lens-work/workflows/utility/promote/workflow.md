---
name: promote
description: Lightweight alias workflow that routes /promote into the core audience-promotion workflow
agent: "@lens"
trigger: /promote command alias packaging
category: utility
phase_name: utility
display_name: Promote Alias
entryStep: './steps/step-01-preflight.md'
---

# /promote Alias Workflow

**Goal:** Confirm the current initiative can be promoted, then delegate execution to the core audience-promotion workflow.

**Your Role:** Operate as a thin routing wrapper only. Do not duplicate the promotion logic already owned by the core audience-promotion workflow.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 runs shared preflight and resolves current promotion context.
- Step 2 reports final-audience exits or routes into the core promotion workflow.

State persists through `initiative_state`, `current_audience`, and `next_audience`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `steps/step-01-preflight.md` - Preflight and audience resolution
2. `steps/step-02-route.md` - Final-audience exit or handoff to core promotion