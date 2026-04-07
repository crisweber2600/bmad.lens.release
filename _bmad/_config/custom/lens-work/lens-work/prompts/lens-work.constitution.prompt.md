---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Resolve and display constitutional governance rules and compliance"
---

# /constitution Prompt

Check or resolve constitutional governance for the current initiative.

## Routing

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
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
