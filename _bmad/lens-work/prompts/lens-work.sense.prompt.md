# /sense — Cross-Initiative Sensing

Run on-demand cross-initiative overlap detection for the current initiative.

## Routing

1. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
2. If not on an initiative branch: `❌ Not on an initiative branch. Use /switch to select an initiative first.`
3. Parse domain, service, and feature from the current initiative root
4. Execute `workflows/governance/cross-initiative/workflow.md`
5. Display the sensing report with overlap analysis and conflict levels

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| No remote branches found | `⚠️ No remote branches found. Ensure remote is configured.` |
| Constitution unavailable | Default to informational gate mode and continue |
