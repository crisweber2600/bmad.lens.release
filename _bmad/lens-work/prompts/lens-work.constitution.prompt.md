---
model: Claude Sonnet 4.6 (copilot)
---

# /constitution Prompt

Check or resolve constitutional governance for the current initiative.

## Routing

1. Run preflight before governance resolution:
	1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
	2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
3. If not on an initiative branch: `❌ Not on an initiative branch. Use /switch to select an initiative first.`
4. Parse domain and service from the current initiative root
5. Execute `workflows/governance/resolve-constitution/workflow.md`
6. Display the resolved constitution for the current initiative

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Governance repo not accessible | `❌ Governance repo not accessible. Run /onboard to verify.` |
