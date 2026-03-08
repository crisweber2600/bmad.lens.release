# /promote Prompt

Promote the current initiative from the current audience tier to the next.

## Routing

1. Load `lifecycle.yaml` from the lens-work module
2. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
3. Use `git-state` skill → `current-audience` to determine the current audience
4. Look up the next audience in the audience chain: small → medium → large → base
5. If already at `base`: report "Initiative is at the final audience — no promotion available"
6. Otherwise: execute `workflows/core/audience-promotion/workflow.md`

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Already at base audience | `✅ Initiative is at final audience — no further promotion needed.` |
| Dirty working directory | Defer to git-orchestration dirty handling (commit/stash/abort) |
