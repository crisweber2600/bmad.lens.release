# Dry Run

Preview the full migration plan without making any changes. This step is mandatory before execution.

## Outcome

A complete report of every action that would be taken — feature.yaml paths to be created, feature-index.yaml entries to be added, summary stubs to be written — with no files written or modified.

## Process

For each feature in the migration plan, run with `--dry-run`:

```bash
python3 ./scripts/migrate-ops.py migrate-feature \
  --governance-repo {governance_repo} \
  --old-id {old_id} \
  --feature-id {feature_id} \
  --domain {domain} \
  --service {service} \
  --username {username} \
  --dry-run
```

## Output Shape

```json
{
  "status": "pass",
  "feature_id": "auth-login",
  "dry_run": true,
  "planned_actions": [
    "Create feature.yaml at {governance_repo}/features/platform/identity/auth-login/feature.yaml",
    "Update feature-index.yaml at {governance_repo}/feature-index.yaml",
    "Create summary stub at {governance_repo}/summaries/auth-login.md"
  ],
  "feature_yaml_created": false,
  "index_updated": false
}
```

## Conflict Check

Before running the dry run for each feature, check for conflicts:

```bash
python3 ./scripts/migrate-ops.py check-conflicts \
  --governance-repo {governance_repo} \
  --feature-id {feature_id} \
  --domain {domain} \
  --service {service}
```

If `"conflict": true`, surface the conflict to the user and skip that feature in the dry-run report. Do not proceed with a conflicting feature without explicit override confirmation.

## After Dry Run

Present a summary table to the user:

| Feature ID | Old Branch | Planned Actions | Conflict |
|-----------|------------|----------------|---------|
| auth-login | platform-identity-auth-login | feature.yaml, index entry, summary | No |

Then ask for confirmation:
- "Proceed with migration for all N features? (yes/no)"
- OR "Select features to migrate: (all/list numbers/no)"

Do not proceed without explicit confirmation.
