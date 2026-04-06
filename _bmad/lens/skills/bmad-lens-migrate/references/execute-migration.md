# Execute Migration

Execute the migration plan after dry-run confirmation. Creates new branch artifacts, populates feature-index.yaml, and writes summary stubs on main.

## Outcome

For each confirmed feature:
- `feature.yaml` created at `{governance_repo}/features/{domain}/{service}/{featureId}/feature.yaml`
- Entry added to `{governance_repo}/feature-index.yaml`
- Summary stub created at `{governance_repo}/summaries/{featureId}.md`

Old branches are NOT deleted at this step. Cleanup is a separate, explicit operation.

## Pre-execution Checklist

1. Dry-run has been shown to the user ✓
2. User has confirmed the migration ✓
3. Conflicts have been reviewed and resolved or skipped ✓

## Execute Single Feature

```bash
python3 ./scripts/migrate-ops.py migrate-feature \
  --governance-repo {governance_repo} \
  --old-id {old_id} \
  --feature-id {feature_id} \
  --domain {domain} \
  --service {service} \
  --username {username}
```

## Output Shape

```json
{
  "status": "pass",
  "feature_id": "auth-login",
  "dry_run": false,
  "feature_yaml_created": true,
  "index_updated": true,
  "summary_created": true
}
```

## Execution Loop

For each confirmed feature in the migration plan:

1. Run `check-conflicts` — if conflict detected, skip and log
2. Run `migrate-feature` (live, no `--dry-run`)
3. Log result: pass / fail / skipped
4. Continue to next feature — do not abort batch on single failure

## feature.yaml Structure

The created feature.yaml follows the Lens Next schema:

```yaml
featureId: auth-login
name: Auth Login
description: Migrated from legacy branch: platform-identity-auth-login
domain: platform
service: identity
phase: preplan
track: full
priority: medium
created: <timestamp>
updated: <timestamp>
team:
  - username: {username}
    role: lead
phase_transitions:
  - phase: preplan
    timestamp: <timestamp>
    user: {username}
migrated_from: platform-identity-auth-login
```

## feature-index.yaml Entry

Added entry format:

```yaml
features:
  - featureId: auth-login
    domain: platform
    service: identity
    migrated_from: platform-identity-auth-login
    added: <timestamp>
```

## Summary Stub (summaries/{featureId}.md)

Written to main branch at `{governance_repo}/summaries/{featureId}.md`:

```markdown
# Auth Login

**Feature ID:** auth-login
**Domain:** platform
**Service:** identity
**Migrated from:** platform-identity-auth-login
**Migration date:** <timestamp>

## Summary

_To be filled in._
```

## Completion Summary

After all features are processed, show:

```
Migration complete:
  ✓ N features migrated successfully
  ✗ N features failed (see errors above)
  ⚠ N features skipped (conflicts)

Old branches preserved. To remove them, run cleanup explicitly.
```

## Cleanup Step

Cleanup is a **separate, explicit operation** and must never happen automatically.

Only run cleanup after:
1. Migration has completed successfully
2. New branches and feature.yaml files have been verified
3. User explicitly confirms: "Delete old branches? (yes/no)"

Cleanup deletes the directories under `{governance_repo}/branches/` for migrated features only. Failed or skipped features are not cleaned up.
