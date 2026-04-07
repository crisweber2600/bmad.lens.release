# Scan Legacy Branches

Detect old-model branches in the governance repository and build a migration plan.

## Outcome

A structured migration plan listing all detected legacy features with their derived domain, service, and feature ID, proposed new branch names, discovered milestones, and inferred current state. Conflicts with existing new-model features are surfaced.

## Process

Run the scan operation:

```bash
python3 ./scripts/migrate-ops.py scan \
  --governance-repo {governance_repo}
```

With an optional custom branch pattern:

```bash
python3 ./scripts/migrate-ops.py scan \
  --governance-repo {governance_repo} \
  --branch-pattern "^your-pattern$"
```

The script scans `{governance_repo}/branches/` for directories matching the legacy pattern `^([a-z0-9-]+)-([a-z0-9-]+)-([a-z0-9-]+)(?:-([a-z0-9-]+))?$`. It groups milestone branches under their base branch, derives domain/service/featureId, and detects conflicts.

## Output Shape

```json
{
  "status": "pass",
  "legacy_features": [
    {
      "old_id": "platform-identity-auth-login",
      "derived_domain": "platform",
      "derived_service": "identity",
      "feature_id": "auth-login",
      "milestones": ["planning", "dev"],
      "proposed": {
        "base_branch": "auth-login",
        "plan_branch": "auth-login-plan"
      },
      "state": "dev"
    }
  ],
  "total": 1,
  "conflicts": []
}
```

## Branch Grouping Logic

The scanner uses prefix-matching to identify milestone branches:
- If directory `A-B-C-D` exists alongside `A-B-C-D-planning`, then `planning` is a milestone of feature `A-B-C-D`
- The base branch (`A-B-C-D`) is used to derive: domain=A, service=B, featureId=C-D
- Standalone entries (not a suffix of any other) are always treated as base branches

## Conflict Detection

A conflict is detected when `{governance_repo}/features/{domain}/{service}/{featureId}/feature.yaml` already exists for the derived featureId. Conflicts are listed separately and do not block other features from appearing in the migration plan.

## After Scan

Present the migration plan as a table to the user:

| Old Branch | Feature ID | Domain | Service | Milestones | State | Conflict |
|------------|------------|--------|---------|-----------|-------|---------|
| platform-identity-auth-login | auth-login | platform | identity | planning, dev | dev | No |

Then offer to proceed to dry-run: "Ready to preview the migration? (yes/no)"
