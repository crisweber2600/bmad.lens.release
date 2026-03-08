# /constitution Prompt

Check or resolve constitutional governance for the current initiative.

## Routing

1. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
2. If not on an initiative branch: `❌ Not on an initiative branch. Use /switch to select an initiative first.`
3. Parse domain and service from the current initiative root
4. Execute `workflows/governance/resolve-constitution/workflow.md`
5. Display the resolved constitution for the current initiative

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Governance repo not accessible | `❌ Governance repo not accessible. Run /onboard to verify.` |
