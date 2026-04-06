# Auto-Publish

## Purpose

Auto-publish ensures every planning artifact is committed atomically: the full document lands on the plan branch *and* the extracted summary plus index update land on main in a single logical operation. There is no "commit now, sync later" — if the two-phase commit fails, the artifact is not committed at all.

## The Two-Phase Commit

Every artifact commit is a two-phase operation coordinated via `bmad-lens-git-orchestration`:

### Phase 1 — Full Artifact to Plan Branch

1. Validate frontmatter (via `quickplan-ops.py validate-frontmatter`).
2. Ensure the plan branch (`{featureId}-plan`) exists; create it from main if not.
3. Write the full artifact file to `{governance-repo}/features/{domain}/{service}/{featureId}/{artifact}` on the plan branch.
4. Commit with message: `feat({featureId}): add {artifact} [phase-1]`

### Phase 2 — Summary and Index to Main

Immediately after Phase 1 succeeds:

1. Extract summary from the artifact frontmatter (via `quickplan-ops.py extract-summary`).
2. Write `{governance-repo}/features/{domain}/{service}/{featureId}/summary.md` on main — creating or updating it.
3. Update `{governance-repo}/feature-index.yaml` on main — add or update the feature entry with `phase`, `goal`, `updated_at`, and `doc_types_present`.
4. Commit both files together with message: `feat({featureId}): update summary and index [{artifact}] [phase-2]`

If Phase 2 fails (e.g., merge conflict on main), roll back by reverting the Phase 1 commit on the plan branch, report the error, and halt.

## Commit Message Format

| Phase | Format |
|-------|--------|
| Phase 1 | `feat({featureId}): add {artifact}` |
| Phase 2 | `feat({featureId}): update summary and index [{artifact}]` |
| Stories batch | `feat({featureId}): add {N} stories (sprint {sprintNumber})` |

## Summary.md Format

The `summary.md` on main is a lightweight snapshot for cross-feature context loading:

```markdown
# Summary: {featureId}

**Phase:** {current phase}
**Goal:** {goal from frontmatter}
**Status:** {status from most recent planning doc}
**Updated:** {updated_at}

## Key Decisions

{key_decisions list from most recent planning doc}

## Open Questions

{open_questions list from most recent planning doc}

## Artifacts Present

{list of artifact files present on plan branch}
```

## feature-index.yaml Entry Format

```yaml
{featureId}:
  domain: {domain}
  service: {service}
  phase: {phase}
  track: {track}
  goal: "{goal}"
  updated_at: "{ISO timestamp}"
  docs_present:
    - business-plan
    - tech-plan
    - sprint-plan
    - stories
```

## Idempotency

Auto-publish is safe to retry:
- If Phase 1 already exists (same content), skip Phase 1 and attempt Phase 2.
- If Phase 2 already reflects the current artifact (same `updated_at`), skip Phase 2.
- Never create duplicate commits.

## Error Handling

| Error | Action |
|-------|--------|
| Frontmatter validation failure | Halt before Phase 1; report validation errors |
| Plan branch creation failure | Halt; report error with governance repo and branch name |
| Phase 1 commit failure | Halt; do not attempt Phase 2 |
| Phase 2 merge conflict | Roll back Phase 1; report conflict details; suggest `git pull` and retry |
| Phase 2 partial write (summary OK, index fails) | Attempt index update again; report if it fails twice |

## Integration

Auto-publish is invoked at the end of every pipeline phase:

```
[business-plan] → auto-publish → [tech-plan] → auto-publish → ...
```

QuickPlan calls `bmad-lens-git-orchestration` to perform the actual git operations. Auto-publish in this reference file defines the contract; git-orchestration implements it.
