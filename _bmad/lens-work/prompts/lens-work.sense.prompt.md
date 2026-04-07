---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Run cross-initiative overlap detection and sensing scan"
---

# /sense Prompt

Run cross-initiative overlap detection for the current initiative.

## Routing

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Use `git-state` skill → `current-initiative` to confirm the current initiative context.
3. Execute `workflows/governance/cross-initiative/workflow.md`.

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Missing authority repos | `❌ Authority repos are not available. Run /onboard first.` |