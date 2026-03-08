# /sprintplan Workflow

**Phase:** Router
**Purpose:** Execute the sprintplan phase — produce sprint plans and user stories.
**Agent:** Bob (Scrum Master)
**Audience:** large (requires promotion from medium)
**Predecessor:** devproposal (must be complete — PR merged)

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes `sprintplan`
- DevProposal phase PR is merged (predecessor enforcement)
- Initiative has been promoted to large audience (`{root}-large` branch exists)

## Steps

### Step 1: Phase Router Validation

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `sprintplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Check predecessor: devproposal PR is merged
4. Check audience level: current audience must be `large`
5. If not on large audience:
   ```
   ❌ Phase `sprintplan` requires `large` audience.
      Current audience: {current_audience}
      Run `/promote` to promote to large audience first.
   ```
6. If valid: create phase branch `{initiative-root}-large-sprintplan` using git-orchestration

### Step 2: Load Dev Proposal Artifacts

Load devproposal artifacts as input context:

- `phases/devproposal/epics.md` — epics and stories to plan sprints from

Also load all planning artifacts for context:
- `phases/preplan/product-brief.md`
- `phases/businessplan/prd.md`
- `phases/techplan/architecture.md`

### Step 3: Delegate to Scrum Master Agent

Delegate sprint planning to Bob (scrum master agent):

```
## Sprint Plan — Generating...
```

| Artifact | Path | Required |
|----------|------|----------|
| Sprint Status | `phases/sprintplan/sprint-status.yaml` | Yes |
| Story Files | `phases/sprintplan/stories/{story-key}.md` | Yes |

All artifacts saved to: `_bmad-output/lens-work/initiatives/{domain}/{service}/phases/sprintplan/`

### Step 4: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/sprintplan/`
2. Commit: `[SPRINTPLAN] {initiative-root} — sprint plan and stories complete`
3. Push to remote

### Step 5: Report Completion

```
✅ SprintPlan phase complete

## Artifacts Produced
- sprint-status.yaml ✅
- stories/{story-count} story files ✅

## Next Step
SprintPlan artifacts are committed and pushed. Your PR will be created
automatically. After it merges, run `/promote` to advance to base audience.
Development execution happens outside the planning lifecycle.
```

## Notes

- sprintplan is the ONLY phase in large audience
- After sprintplan PR merges → user runs `/promote` to advance to base
- Sprint-status.yaml and story files are consumed by `/dev` (Epic 5.3)
