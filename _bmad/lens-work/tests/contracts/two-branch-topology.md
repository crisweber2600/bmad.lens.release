# Contract Test: 2-Branch Topology

**Skills Under Test:** git-state, git-orchestration, feature-yaml
**Purpose:** Verify 2-branch topology operations create correct branch structure, route artifacts to correct branches, and track milestones via feature.yaml.

---

## Test Cases

### Branch Creation

| Feature ID | Expected Code Branch | Expected Plan Branch | Track Topology | Result |
|-----------|---------------------|---------------------|----------------|--------|
| `oauth` | `oauth` | `oauth-plan` | 2-branch | ✅ Both created |
| `payments-auth` | `payments-auth` | `payments-auth-plan` | 2-branch | ✅ Both created |
| `oauth` | `oauth-techplan` | n/a | legacy | ✅ Milestone branch (legacy behavior) |

### Topology Resolution

| Track | Topology Field | feature_yaml Field | Expected Behavior |
|-------|---------------|-------------------|-------------------|
| `full` | `legacy` | `false` | Milestone branches, initiative-state.yaml |
| `full` | `2-branch` | `true` | featureId + featureId-plan, feature.yaml |
| `express` | `legacy` | `false` | Single branch model (unchanged) |
| `hotfix` | `legacy` | `false` | Milestone branches (unchanged) |

### Artifact Routing (2-branch)

| Artifact Phase | Target Branch | Target Folder | Notes |
|---------------|---------------|---------------|-------|
| preplan draft | `{featureId}-plan` | `drafts/` | Working draft |
| businessplan draft | `{featureId}-plan` | `drafts/` | Working draft |
| approved artifact | `{featureId}` | `artifacts/` | Published via commit-and-publish |
| review report | `{featureId}-plan` | `reviews/` | Review output |
| feature.yaml | `{featureId}` | root | Authoritative state |

### Milestone Tracking (2-branch)

| Action | feature.yaml Field | Expected Value |
|--------|-------------------|----------------|
| Init feature | `current_milestone` | `techplan` |
| Complete techplan | `current_milestone` | `devproposal` |
| Complete devproposal | `current_milestone` | `sprintplan` |
| Complete sprintplan | `current_milestone` | `dev-ready` |

### Merge Chain (2-branch)

| Source | Target | Gate | PR Count |
|--------|--------|------|----------|
| `{featureId}` | `main` | constitution-gate | 1 (single PR) |

### Backward Compatibility

| Scenario | Expected |
|----------|----------|
| Legacy track with no topology field | Defaults to `legacy` behavior |
| Legacy track with feature_yaml: false | No feature.yaml created or checked |
| Mixed tracks (some legacy, some 2-branch) | Each track uses its own topology independently |
| Constitution topology_override | Override applies per domain/service scope |

## Verification Method

1. For branch creation: invoke `git-orchestration` → `create-feature-branches` with topology config and verify branches exist
2. For artifact routing: invoke `git-orchestration` → `commit-and-publish` and verify files land on correct branches
3. For milestone tracking: read `feature.yaml` after each phase completion and verify `current_milestone` value
4. For merge chain: verify single PR created from `{featureId}` to `main`
5. For backward compatibility: run legacy track operations and verify no 2-branch behavior leaks
