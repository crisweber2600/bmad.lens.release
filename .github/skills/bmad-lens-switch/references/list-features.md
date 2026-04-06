# List Features

Discover and enumerate available features from `feature-index.yaml`.

## When to Use

- When the user asks "what features are available?", "list features", "show me what I can switch to"
- When helping the user select a target feature before switching
- When checking feature status across the repo

## Source

Feature list always reads from `feature-index.yaml` at the governance repo root. This file is always read from `main` — no branch switching is performed. The index is the authoritative source for listing; individual `feature.yaml` files are only read during a `switch` operation.

## Process

Run the list operation:

```bash
python3 ./scripts/switch-ops.py list \
  --governance-repo {governance_repo}
```

Optional status filter (default: active only):

```bash
# Show all features including archived
python3 ./scripts/switch-ops.py list \
  --governance-repo {governance_repo} \
  --status-filter all

# Show only archived
python3 ./scripts/switch-ops.py list \
  --governance-repo {governance_repo} \
  --status-filter archived
```

## Output

```json
{
  "status": "pass",
  "features": [
    {
      "id": "auth-login",
      "domain": "platform",
      "service": "identity",
      "status": "active",
      "owner": "cweber",
      "summary": "User authentication flow with JWT tokens"
    },
    {
      "id": "user-profile",
      "domain": "platform",
      "service": "identity",
      "status": "active",
      "owner": "amelia",
      "summary": "User profile management and preferences"
    }
  ],
  "total": 2
}
```

## Display Format

Present results as a table grouped by domain/service:

```
Available features (2):

PLATFORM / IDENTITY
  auth-login     active   cweber    User authentication flow with JWT tokens
  user-profile   active   amelia    User profile management and preferences
```

Highlight the currently active feature (if any) with `→` prefix.

## Errors

| Error | Exit code | Cause |
|-------|-----------|-------|
| `feature-index.yaml not found at {path}` | 1 | Index file missing from governance repo |
| `Failed to parse feature-index.yaml: ...` | 1 | YAML parse error in index |
