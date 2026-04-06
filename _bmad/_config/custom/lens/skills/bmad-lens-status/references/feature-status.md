# Feature Status

Get the current detailed status of a specific feature. Reads `feature.yaml` from the plan branch (not from main).

## When to Use

- User asks "what's the status of auth-login?"
- User asks "is auth-login stale?"
- User needs current phase, track, team, and staleness for a specific feature

## Resolution

1. Validate `featureId`, `domain`, and `service` (safe identifier pattern)
2. Resolve `feature.yaml` path: `{governance_repo}/features/{domain}/{service}/{featureId}/feature.yaml`
3. Return structured status

## Staleness Alert

If `context.stale = true` in `feature.yaml`, open the response with:

> ⚠️ **Stale context** — Related features have updated since last pull. Run `/lens context-refresh` before continuing work.

Then show the status table.

## Output Format

Lead with the staleness alert if applicable, then a summary table:

```
Feature: auth-login
─────────────────────────────────────────
Phase:       dev
Track:       quickplan
Priority:    high
Team lead:   alice
Updated:     2026-04-01T10:00:00Z
Stale:       no
```

If the user asks for more detail, show team members, dependencies, and target repos.

## Script

```bash
uv run scripts/status-ops.py feature \
  --governance-repo {governance_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service}
```

## Output JSON

```json
{
  "status": "pass",
  "feature": {
    "id": "auth-login",
    "name": "User Authentication",
    "phase": "dev",
    "track": "quickplan",
    "priority": "high",
    "stale": false,
    "team": [{"username": "alice", "role": "lead"}],
    "updated_at": "2026-04-01T10:00:00Z",
    "domain": "platform",
    "service": "identity"
  }
}
```

## Error Cases

| Error | Response |
|-------|---------|
| Feature not found | Report the gap: "Feature `{featureId}` not found at `features/{domain}/{service}/{featureId}/feature.yaml`" |
| Invalid featureId | Report validation error — never attempt path construction with unsafe input |
| Empty feature.yaml | Report the gap: "feature.yaml exists but is empty or unparseable" |
