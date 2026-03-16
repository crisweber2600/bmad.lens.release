# Contract Test: Provider Adapter Operations

**Skill Under Test:** git-orchestration (provider operations section)
**Purpose:** Verify PR operations work correctly through the provider abstraction.

---

## Provider Detection

| Remote URL | Expected Provider |
|-----------|-------------------|
| `https://github.com/user/repo.git` | `github` |
| `git@github.com:user/repo.git` | `github` |
| `https://dev.azure.com/org/project/_git/repo` | `azure-devops` |
| `https://org.visualstudio.com/project/_git/repo` | `azure-devops` |
| `https://gitlab.com/user/repo.git` | `unknown` |
| `https://bitbucket.org/user/repo.git` | `unknown` |

## Authentication Validation

### GitHub (PAT via environment variable)

| Scenario | Expected Output |
|----------|----------------|
| `GITHUB_PAT` env var set + valid | `{ authenticated: true, user: "username", pat_source: "GITHUB_PAT environment variable" }` |
| `GH_TOKEN` env var set + valid | `{ authenticated: true, user: "username", pat_source: "GH_TOKEN environment variable" }` |
| PAT in profile.yaml + valid | `{ authenticated: true, user: "username", pat_source: "profile.yaml" }` |
| No PAT found anywhere | `{ authenticated: false, error: "Run store-github-pat script" }` |
| Invalid PAT (401 from REST API) | `{ authenticated: false, error: "PAT rejected by GitHub API" }` |

## PR Operations

### `create-pr`

| Input | Expected |
|-------|----------|
| Valid source/target branches | PR created, URL returned; PR number optional when provider exposes it |
| Source = target | Error: source and target must differ |
| Non-existent source branch | Error from provider |

### `query-pr-status`

| Scenario | Expected State |
|----------|---------------|
| Open PR exists | `{ state: "open" }` |
| Merged PR exists | `{ state: "merged", merged_at: "{timestamp}" }` |
| Closed PR (not merged) | `{ state: "closed" }` |
| No PR exists | `{ state: null }` or empty result |

### `list-prs`

| Filter | Expected |
|--------|----------|
| By target branch, state=merged | Only merged PRs to that branch |
| By source+target, state=open | Specific open PR if exists |
| No matching PRs | Empty list |

## Credential Security (NFR4)

### Verification Steps

1. Run `grep -r "token\|pat\|password\|secret\|credential" --include="*.yaml" --include="*.md" --include="*.csv"` across all git-tracked files
2. Expected: ZERO matches for actual credential values
3. Confirm PATs are only read from environment variables, never echoed to stdout

## Verification Method

Execute each provider operation via REST API with PAT and validate the output structure matches the contract. For untestable scenarios (no PR exists), verify error handling produces the documented error format.
