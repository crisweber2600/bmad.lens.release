# Contract Test: Branch Name Parsing

**Skill Under Test:** git-state
**Purpose:** Verify branch name parsing correctly extracts initiative root, audience, and phase.

---

## Test Cases

### Parse Initiative Root

| Input Branch | Expected Root | Expected Audience | Expected Phase |
|-------------|---------------|-------------------|----------------|
| `foo-bar-auth` | `foo-bar-auth` | null | null |
| `foo-bar-auth-small` | `foo-bar-auth` | `small` | null |
| `foo-bar-auth-small-preplan` | `foo-bar-auth` | `small` | `preplan` |
| `foo-bar-auth-medium-devproposal` | `foo-bar-auth` | `medium` | `devproposal` |
| `foo-bar-auth-large-sprintplan` | `foo-bar-auth` | `large` | `sprintplan` |
| `foo-bar-auth-base` | `foo-bar-auth` | `base` | null |

### Non-Initiative Branches

| Input Branch | Expected Behavior |
|-------------|-------------------|
| `main` | Return null initiative |
| `develop` | Return null initiative |
| `feature/epic-1` | Return null initiative |

### Edge Cases

| Input Branch | Expected Root | Notes |
|-------------|---------------|-------|
| `a-small` | `a` | Single-char root |
| `a-b-c-d-small-techplan` | `a-b-c-d` | Multi-segment root |
| `payments-small-businessplan` | `payments` | Domain-only initiative |

### Slug-Safe Validation

| Input Name | Valid | Reason |
|-----------|-------|--------|
| `foo-bar-auth` | ✅ | Lowercase alphanumeric + hyphens |
| `Foo-Bar` | ❌ | Uppercase characters |
| `foo bar` | ❌ | Spaces |
| `foo_bar` | ❌ | Underscores (not slug-safe) |
| `foo--bar` | ❌ | Double hyphens |
| `-foo-bar` | ❌ | Leading hyphen |

## Verification Method

For each test case, invoke `git-state` → `current-initiative` and `current-phase` with the input branch, and compare parsed output against expected values.
