# Feature State

## Outcome

Produce a complete picture of a feature's lifecycle state by combining `feature.yaml` metadata with actual git branch existence — surfaces any discrepancies between the two.

## Process

Run:
```
./scripts/git-state-ops.py feature-state \
  --governance-repo {governance_repo} \
  --feature-id {featureId}
```

The script returns JSON. Present the following to the user:

**Phase & Track** — from `feature.yaml` (authoritative)
**Branch Status** — which branches exist vs expected, any missing
**Discrepancies** — cases where feature.yaml phase doesn't match what branches suggest
**Open Work** — any `dev-{username}` branches still active

If `feature.yaml` is missing, report clearly: this feature is git-only (no YAML state) and prompt the user to run the `bmad-lens-feature-yaml` skill to create one.

## Output Fields

| Field | Source | Description |
| ----- | ------ | ----------- |
| `feature_id` | feature.yaml | Canonical identifier |
| `phase` | feature.yaml | Current lifecycle phase |
| `track` | feature.yaml | Execution track |
| `status` | feature.yaml | `active`, `paused`, `complete`, or `warning` |
| `base_branch_exists` | git | Whether `{featureId}` branch exists |
| `plan_branch_exists` | git | Whether `{featureId}-plan` branch exists |
| `dev_branches` | git | List of `{featureId}-dev-{username}` branches found |
| `yaml_path` | git | Resolved path to `feature.yaml` in governance repo |
| `discrepancies` | derived | Conflicts between YAML state and git branch state |
