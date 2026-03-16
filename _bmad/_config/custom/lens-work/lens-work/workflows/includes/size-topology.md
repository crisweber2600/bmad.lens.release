# Audience → Branch Topology Mapping

**Type:** Workflow include
**Purpose:** Map audience tiers to branch naming patterns for consistent topology operations.

## Usage

Referenced by phase-lifecycle, audience-promotion, and init-initiative workflows to derive correct branch names from audience context.

## Audience Chain

```
small → medium → large → base
```

## Branch Name Derivation

### Initiative Root Branch

```
{initiative-root}
```

Created at `/new-*`. This is the top-level branch for the initiative.

### Audience Branch

```
{initiative-root}-{audience}
```

| Audience | Branch Example | Created When |
|----------|---------------|-------------|
| small | `foo-bar-auth-small` | At init (`/new-*`) — always created |
| medium | `foo-bar-auth-medium` | Lazy — on first promotion to medium |
| large | `foo-bar-auth-large` | Lazy — on first promotion to large |
| base | `foo-bar-auth-base` | Lazy — on first promotion to base |

### Phase Branch

```
{initiative-root}-{audience}-{phase}
```

| Phase | Audience | Branch Example |
|-------|----------|---------------|
| preplan | small | `foo-bar-auth-small-preplan` |
| businessplan | small | `foo-bar-auth-small-businessplan` |
| techplan | small | `foo-bar-auth-small-techplan` |
| devproposal | medium | `foo-bar-auth-medium-devproposal` |
| sprintplan | large | `foo-bar-auth-large-sprintplan` |

## Merge Chain Topology

### Phase → Audience (phase completion)

```
{root}-{audience}-{phase}  →  {root}-{audience}
```

PR created automatically at phase end. Merged = phase complete.

### Audience → Audience (promotion)

```
{root}-small   →  {root}-medium    (adversarial review gate)
{root}-medium  →  {root}-large     (stakeholder approval gate)
{root}-large   →  {root}-base      (constitution gate)
```

Target audience branch created lazily at promotion time from `{root}` (initiative root branch) if it doesn't exist.

## Audience Branch Existence as Signal

| Branch Exists | Meaning |
|--------------|---------|
| `{root}-small` | Initiative initialized |
| `{root}-medium` | Promotion to medium attempted or completed |
| `{root}-large` | Promotion to large attempted or completed |
| `{root}-base` | Initiative reached final audience |

Check PR state to determine if promotion is complete (merged) or in-progress (open).
