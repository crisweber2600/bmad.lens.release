# /dev Workflow

**Phase:** Router
**Purpose:** Execute the dev phase — implement user stories with code review cycles.
**Agent:** Amelia (Developer)
**Audience:** base (requires promotion from large)
**Predecessor:** sprintplan (must be complete — PR merged)

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes dev execution
- SprintPlan phase PR is merged (predecessor enforcement)
- Initiative has been promoted to base audience (`{root}-base` or base-equivalent exists)
- Sprint-status.yaml and story files are available

## Steps

### Step 1: Phase Router Validation

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm dev is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Check predecessor: sprintplan PR is merged
4. Check audience level: current audience must be `base`
5. If not on base audience:
   ```
   ❌ Phase `dev` requires `base` audience.
      Current audience: {current_audience}
      Run `/promote` to promote to base audience first.
   ```

### Step 2: Load Sprint Plan

Load sprint plan artifacts:

- `phases/sprintplan/sprint-status.yaml` — story list and priority
- `phases/sprintplan/stories/` — individual story files

### Step 3: Identify Next Story

Read `sprint-status.yaml` to find the next story to implement:

1. Find the first story with status `ready-for-dev`
2. If no `ready-for-dev` stories, check for `in-progress` (resume)
3. If all stories are `done`:
   ```
   ✅ All stories in the sprint are complete!
   Run `/promote` to finalize, or `/status` to review.
   ```

### Step 4: Delegate to Developer Agent

Delegate story implementation to Amelia (developer agent):

**Key distinction:**
- **Control repo (Domain 1):** Story artifacts, sprint status, implementation notes
- **Target repo (TargetProjects/):** Actual code changes

Story implementation cycle:
1. Read story file for requirements and acceptance criteria
2. Create feature branch in target project: `feature/{epic-key}-{story-key}`
3. Implement code changes in `TargetProjects/`
4. Write unit tests and integration tests
5. Update story status and implementation notes in control repo

### Step 5: Commit Story Artifacts

Using git-orchestration skill:

**Control repo commits:**
1. Updated story file (status, implementation notes, file list)
2. Updated sprint-status.yaml (story status progression)
3. Commit: `[DEV] {initiative-root} — {story-key} implementation`

**Target repo commits (by developer agent):**
1. Code changes in feature branch
2. Test files
3. Commit: `feat({story-key}): {description}`

### Step 6: Code Review Cycle

After story implementation:

1. Create PR in target repo: `feature/{epic-key}-{story-key}` → `feature/{epic-key}`
2. PR created via provider-adapter using phase-lifecycle PR automation
3. Story status updated to `review`
4. After review merge → advance to next story (go to Step 3)

### Step 7: Sprint Completion

When all stories in the sprint are complete:

```
✅ Sprint complete — all stories implemented and reviewed

## Sprint Summary
- Stories completed: {count}
- PRs merged: {count}
- Target project branches: {list}

## Next Step
Run `/status` to see the full picture, or `/promote` if all
dev execution is complete.
```

## Target Project Branching (GitFlow)

| Branch | Pattern | Purpose |
|--------|---------|---------|
| Story | `feature/{epic-key}-{story-key}` | Individual story implementation |
| Epic | `feature/{epic-key}` | Collects story branches |
| Integration | `develop` | Epic branches merge here |
| Release | `release/{version}` | Release candidate |
| Production | `main` | Production code |

Merge chain:
```
feature/{epic}-{story} → feature/{epic} → develop → release/{ver} → main
```
