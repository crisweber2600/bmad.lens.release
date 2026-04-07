# Finalize Feature

Archive the feature atomically: update feature.yaml to `complete`, update feature-index.yaml to `archived`, write the final summary, and commit to main.

## Outcome

The feature is permanently archived. feature.yaml phase is `complete`, feature-index.yaml status is `archived`, `summary.md` is written to the feature directory, and all changes are committed to main.

## Pre-conditions

Before calling finalize, confirm all of the following:

- [ ] `check-preconditions` returned status `pass` or `warn` (not `fail`)
- [ ] `retrospective.md` exists in the feature directory (or user confirmed skip)
- [ ] Project documentation captured (at minimum `docs/README.md`)
- [ ] User has explicitly confirmed finalize (this is irreversible)

## Confirmation Gate

Always display this confirmation before executing:

```
┌─────────────────────────────────────────────┐
│  FINALIZE FEATURE — THIS IS IRREVERSIBLE     │
│                                              │
│  Feature:  {featureId}                       │
│  Phase:    dev → complete                    │
│  Index:    {status} → archived               │
│                                              │
│  Archive will include:                       │
│  ✓ retrospective.md                          │
│  ✓ docs/README.md                            │
│  ✓ summary.md (will be written now)          │
│                                              │
│  Confirm? (yes/no)                           │
└─────────────────────────────────────────────┘
```

Only proceed on explicit `yes`.

## Process

Run the finalize operation:

```bash
python3 ./scripts/complete-ops.py finalize \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service}
```

For dry-run preview (show what would change without writing):

```bash
python3 ./scripts/complete-ops.py finalize \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service} \
  --dry-run
```

## What the Script Does

1. Reads current feature.yaml
2. Updates `phase` to `complete` and sets `completed_at` to current UTC ISO timestamp
3. Reads `{governance-repo}/feature-index.yaml` and updates the matching entry's `status` to `archived` and `updated_at` to current UTC ISO timestamp
4. Writes `{feature-dir}/summary.md` with the archive summary
5. All writes are atomic (temp file + rename)

## Output

```json
{
  "status": "pass",
  "feature_id": "my-feature",
  "archived_at": "2026-04-06T02:03:34Z",
  "feature_yaml_path": "{governance-repo}/features/{domain}/{service}/{featureId}/feature.yaml",
  "index_updated": true
}
```

## Post-Finalize Confirmation

After successful finalize, display the complete archive manifest:

```
Feature archived successfully.

Archive: {governance-repo}/features/{domain}/{service}/{featureId}/

Planning artifacts:
  feature.yaml          ← phase: complete
  brief.md (if present)
  specs/ (if present)

Problems captured:
  problems/ (if present)

Retrospective:
  retrospective.md

Project documentation:
  docs/README.md
  docs/deployment.md (if present)
  docs/api.md (if present)

Archive record:
  summary.md            ← written at {archived_at}

Feature index:
  feature-index.yaml    ← status: archived
```

## Error Handling

If finalize fails midway (e.g., disk error after writing feature.yaml but before updating feature-index):

- The script uses atomic writes — incomplete states are not written to disk
- If the index fails to update, report the error and provide the manual fix command:

```bash
# Manual index update if script failed:
python3 ./scripts/complete-ops.py finalize \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service}
```
