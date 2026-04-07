# Active Features

## Outcome

Enumerate all features in the governance repo that have active git branches, matching them with their `feature.yaml` state — providing a workspace-wide inventory of in-flight work.

## Process

Run:
```
./scripts/git-state-ops.py active-features \
  --governance-repo {governance_repo} \
  [--domain {domain}] \
  [--phase {phase}] \
  [--track {track}]
```

The script scans for `feature.yaml` files under the repo's features directory, checks branch existence for each, and returns a combined list. Apply filter flags to narrow the scope.

Present as a table with columns: Feature ID, Phase, Track, Status, Has Plan Branch, Dev Branches.

If a feature has branches but no `feature.yaml`, flag it as **unregistered** — it may be a stale branch or pre-Lens feature.

If a feature has a `feature.yaml` but no branches, flag it as **ghost** — YAML exists but no active git work.

## Filter Options

| Flag | Description | Example |
| ---- | ----------- | ------- |
| `--domain` | Filter by domain | `--domain payments` |
| `--phase` | Filter by lifecycle phase | `--phase dev` |
| `--track` | Filter by execution track | `--track hotfix` |

## Output Structure

```json
{
  "features": [
    {
      "feature_id": "payments-checkout-v2",
      "domain": "payments",
      "service": "checkout",
      "phase": "dev",
      "track": "full",
      "status": "active",
      "base_branch_exists": true,
      "plan_branch_exists": true,
      "dev_branches": ["payments-checkout-v2-dev-alice"],
      "yaml_path": "features/payments/checkout/payments-checkout-v2/feature.yaml"
    }
  ],
  "unregistered_branches": [],
  "ghost_yamls": [],
  "total_active": 1
}
```
