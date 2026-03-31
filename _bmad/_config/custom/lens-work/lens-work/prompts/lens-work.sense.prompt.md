---
model: Claude Sonnet 4.6 (copilot)
---

# /sense Prompt

Run cross-initiative overlap detection for the current initiative.

## Routing

1. Run preflight before sensing:
   1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
   2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Use `git-state` skill → `current-initiative` to confirm the current initiative context.
3. Execute `workflows/governance/cross-initiative/workflow.md`.

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Missing authority repos | `❌ Authority repos are not available. Run /onboard first.` |