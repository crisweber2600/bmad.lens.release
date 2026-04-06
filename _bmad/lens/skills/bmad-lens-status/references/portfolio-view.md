# Portfolio View

Get all active features across all domains. **Reads from `feature-index.yaml` on `main` only — no branch switching.**

## When to Use

- User asks "what's the full portfolio look like?"
- User wants to see all active features with owners and staleness
- User wants a health check across the entire governance repo

## Key Constraint

This capability **never switches branches**. All data comes from `feature-index.yaml` on `main`. This is intentional — the portfolio view must be instant and always current relative to `main`.

## Status Filter

| Filter | Includes |
|--------|---------|
| `active` (default) | All features except archived |
| `all` | All features including archived |
| `archived` | Only archived features |

Active = any status value except `archived`. This includes `active`, `paused`, and any other in-progress status.

## Output Format

Open with a health summary line, then a table:

```
Portfolio: 6 active features  ⚠️ 2 stale
──────────────────────────────────────────────────────────────────────────────────
Feature            Domain      Service    Phase        Owner    Status
──────────────────────────────────────────────────────────────────────────────────
auth-login         platform    identity   dev          alice    active
⚠️ auth-mfa        platform    identity   techplan     bob      active
api-gateway        platform    gateway    sprintplan   carol    active
billing-v2         payments    core       dev          dave     active
⚠️ reporting-v3    analytics   bi         businessplan eve      active
notifications      comms       push       preplan      alice    active
```

Staleness alerts (⚠️) appear on the feature row. The summary line surfaces the aggregate stale count prominently.

## Staleness Surface Rule

If any features are stale, open the entire response with:

> ⚠️ **{N} feature(s) have stale context.** Related features have updated since last pull. Review stale features before proceeding with planning work.

Then show the table.

## Script

```bash
# Active features (default)
uv run scripts/status-ops.py portfolio \
  --governance-repo {governance_repo}

# All features including archived
uv run scripts/status-ops.py portfolio \
  --governance-repo {governance_repo} \
  --status-filter all
```

## Output JSON

```json
{
  "status": "pass",
  "total": 6,
  "stale_count": 2,
  "features": [
    {
      "id": "auth-login",
      "domain": "platform",
      "service": "identity",
      "status": "active",
      "owner": "alice",
      "summary": "User auth with OAuth2 support",
      "phase": "dev",
      "stale": false
    }
  ]
}
```

## Error Cases

| Error | Response |
|-------|---------|
| feature-index.yaml missing | Report the gap: "feature-index.yaml not found at `{governance_repo}/feature-index.yaml`. Run `/lens onboard` or `/lens init` to initialize the governance repo." |
| Empty portfolio | Show empty table with note: "No active features found. Use `/lens init` to start a new feature." |
