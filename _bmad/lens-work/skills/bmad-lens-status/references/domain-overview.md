# Domain Overview

Get all features in a domain. **Reads from `feature-index.yaml` on `main` only — no branch switching.**

## When to Use

- User asks "what's happening in the platform domain?"
- User needs a cross-feature view within a single domain
- User wants to see who owns what in a domain before starting a new feature

## Key Constraint

This capability **never switches branches**. All data comes from `feature-index.yaml` on `main`. Summary text comes from the `summary` field in the index entry. If a feature's summary is missing, surface that gap.

## Output Format

Present a table ordered by phase (active work first):

```
Domain: platform  (4 features)
──────────────────────────────────────────────────────────────────
Feature          Phase        Owner    Status    Summary
──────────────────────────────────────────────────────────────────
auth-login       dev          alice    active    User auth with OAuth2 support
⚠️ auth-mfa      techplan     bob      active    MFA via TOTP — context stale
api-gateway      sprintplan   carol    active    Unified API gateway routing
legacy-cleanup   complete     dave     archived  Old auth cleanup — done
```

Staleness alerts (⚠️) appear inline on the feature row. Do not aggregate them separately in a domain view — they are per-feature annotations.

## Script

```bash
uv run scripts/status-ops.py domain \
  --governance-repo {governance_repo} \
  --domain {domain}
```

## Output JSON

```json
{
  "status": "pass",
  "domain": "platform",
  "features": [
    {
      "id": "auth-login",
      "status": "active",
      "owner": "alice",
      "summary": "User auth with OAuth2 support",
      "phase": "dev",
      "stale": false
    }
  ],
  "total": 1
}
```

## Empty Domain

If a domain has no features in the index, return an empty table with a note:

> No features found in domain `{domain}`. If this is unexpected, verify that features were initialized with `/lens init`.

## Error Cases

| Error | Response |
|-------|---------|
| feature-index.yaml missing | Report the gap: "feature-index.yaml not found at `{governance_repo}/feature-index.yaml`. Governance repo may not be initialized." |
| Invalid domain name | Report validation error |
