---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Promote current initiative to the next audience tier with gate checks"
---

# /promote Prompt

Promote the current initiative from the current audience tier to the next.

## Routing

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
4. Use `git-state` skill → `current-audience` to determine the current audience
5. Look up the next audience in the audience chain: small → medium → large → base
6. If already at `base`: report "Initiative is at the final audience — no promotion available"
7. Otherwise: execute `workflows/utility/promote/workflow.md`

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Already at base audience | `✅ Initiative is at final audience — no further promotion needed.` |
| Dirty working directory | Defer to git-orchestration dirty handling (commit/stash/abort) |
