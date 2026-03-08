# /techplan Workflow

**Phase:** Router
**Purpose:** Execute the techplan phase — produce architecture and technical decision artifacts.
**Agent:** Winston (Architect)
**Audience:** small
**Predecessor:** businessplan (must be complete — PR merged)

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes `techplan`
- Businessplan phase PR is merged (predecessor enforcement)
- Current branch is on the initiative's `small` audience

## Steps

### Step 1: Phase Router Validation

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `techplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Check predecessor: businessplan PR is merged (via provider-adapter `query-pr`)
4. If businessplan not complete:
   ```
   ❌ Phase `techplan` requires `businessplan` to be complete.
      Run `/businessplan` first, then create a PR to merge it.
   ```
5. If valid: create phase branch `{initiative-root}-small-techplan` using git-orchestration

### Step 2: Load Business Artifacts

Load businessplan artifacts from `phases/businessplan/` as input context:

- `prd.md` — requirements driving the architecture
- `ux-design.md` — UX constraints on technical decisions

### Step 3: Delegate to Architect Agent

Delegate architecture production to Winston (architect agent).

```
## Architecture — Generating...
```

| Artifact | Path | Required |
|----------|------|----------|
| Architecture | `phases/techplan/architecture.md` | Yes |

All artifacts saved to: `_bmad-output/lens-work/initiatives/{domain}/{service}/phases/techplan/`

### Step 4: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/techplan/`
2. Commit: `[TECHPLAN] {initiative-root} — architecture document complete`
3. Push to remote

### Step 5: Report Completion

```
✅ TechPlan phase complete

## Artifacts Produced
- architecture.md ✅

## Next Step
TechPlan is the LAST phase in the small audience. Your PR will be created
automatically. After it merges, run `/promote` to advance to medium audience,
then `/devproposal` to continue.
```

## Notes

- techplan is the LAST phase in small audience before promotion to medium
- After techplan PR merges → user runs `/promote` to advance to medium
- Architecture artifacts inform the devproposal phase (next audience)
