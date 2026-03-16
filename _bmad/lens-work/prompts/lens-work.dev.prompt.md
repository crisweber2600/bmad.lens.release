---
---

# /dev Prompt — Epic-Level Implementation Loop

Route to the dev phase workflow via the @lens phase router.
Orchestrates the full implementation cycle for an epic: iterates all stories, implements each with per-task commits, runs adversarial review after each story, fixes issues, then continues to the next story.

## Implementation Target — NOT bmad.lens.release

**⚠️ CRITICAL:** `bmad.lens.release` is a **READ-ONLY authority repo**. It contains BMAD framework code (agents, workflows, lifecycle definitions). It is **NEVER** the implementation target.

The implementation target is the **TargetProject repo** — resolved from `initiative.target_repos[0].local_path` in the initiative config. All code changes, file creation, commits, and PRs go to the TargetProject repo. If you find yourself writing files inside `bmad.lens.release/`, STOP — you are in the wrong repo.

## Inputs

- **Epic number** (required): The epic to implement (e.g., `1`, `2`). All stories belonging to this epic will be discovered and implemented in order.
- **Special instructions** (optional): Freeform guidance that applies to ALL story implementations in this epic. Examples: "Use the repository pattern for data access", "Prioritize performance over readability", "All new endpoints must include OpenAPI annotations". These instructions are injected into implementation guidance for every story.

## Execution

1. **Authority Repo Health Check** (read-only — NO writes to these repos):
   1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`. This is a health check only — `bmad.lens.release` is NOT the implementation target.
   2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Load `lifecycle.yaml` from the lens-work module (read from `bmad.lens.release` — read-only)
3. Invoke phase routing for `dev`:
   - Validate predecessor `sprintplan` PR is merged
   - Validate audience level is `base` (promotion from large required)
   - Create phase branch `{initiative-root}-dev`
4. Execute `workflows/router/dev/workflow.md` with parameters:
   - `epic_number`: the epic number provided by the user
   - `special_instructions`: the optional special instructions provided by the user (empty string if none)

## Write Scope — Target Repo Only (NOT bmad.lens.release)

During `/dev`, ALL implementation writes (file creation, modification, commits) are **strictly scoped to the TargetProject repo folder** resolved from `initiative.target_repos[0].local_path`. The agent MUST NOT modify files in:
- `bmad.lens.release/` (read-only framework — NEVER an implementation target)
- The control repo (bmad.lens.bmad) except `_bmad-output/` state tracking
- The governance repo
- `.github/` adapter layer

**Dev Write Guard:** Before implementing any task, the workflow runs a hard gate (Step 3.Nc) that verifies the working directory is inside the TargetProject repo. If the working directory resolves to `bmad.lens.release/` or any other non-target path, implementation is **BLOCKED**. The guard also rejects any `target_path` that contains `bmad.lens.release`.

## Epic-Level Story Loop

The dev workflow will:
1. Discover all story files matching the epic number
2. Sort stories by story order
3. Display the story list and confirm before proceeding
4. Resolve `initiative_id` from the initiative config (`initiative.id`, e.g., `lens`, `core`)
5. For each story:
   - Load story file and run constitution/pre-implementation gates
   - **Create initiative branch** (`feature/{initiativeId}`) in target repo if not exists — resolves the actual integration branch (develop/main/master) via fallback chain
   - **Create epic branch** (`feature/{initiativeId}-{epic-key}`) from initiative branch if not exists
   - **Create story branch** (`feature/{initiativeId}-{epic-key}-{story-key}`) — **STORY CHAINING**: first story branches from epic, subsequent stories branch from the previous story
   - **ASSERT current branch is the story branch** before ANY task implementation begins
   - Implement all tasks — each task gets its own commit with multi-line message (Story/Task/Epic metadata)
   - **Each commit MUST target the story branch** — commits directly to the epic branch are BLOCKED
   - **Push after every commit** with explicit `git push origin "{story-branch}"` — no bare `git push`
   - Run adversarial code review
   - If issues found: fix and re-review (max 2 passes)
   - **Verify non-empty diff** — story branch MUST have commits ahead of epic branch before PR creation
   - **Auto-create PR** from story branch → epic branch (only after review gate passes AND diff is non-empty)
   - **NO per-story stop** — PR is created but execution continues to the next story immediately
   - Mark story done and commit state
6. After all stories: run epic completion gate, retrospective
7. **Auto-create epic PR** from epic branch → **initiative branch** (`feature/{initiativeId}`)
8. **HARD STOP at epic level** — wait for epic→initiative PR to be merged before proceeding
9. Update state

## Branch Hierarchy

```
feature/{initiativeId}                              ← initiative branch (merge target for epics)
  └── feature/{initiativeId}-{epic-key}             ← epic branch (merge target for stories)
        ├── feature/{initiativeId}-{epic-key}-{story-1}   ← first story (branches from epic)
        ├── feature/{initiativeId}-{epic-key}-{story-2}   ← chains off story-1
        └── feature/{initiativeId}-{epic-key}-{story-3}   ← chains off story-2
```

## Branch Discipline — Story-Branch-First + Story Chaining

**CRITICAL INVARIANT:** During task implementation, the agent MUST be on the **story branch**, not the epic branch.

- **Initiative branch** (`feature/{initiativeId}`) receives code ONLY via merged epic→initiative PRs.
- **Epic branch** (`feature/{initiativeId}-{epic-key}`) is a **merge-only** branch. Code enters it ONLY via merged story→epic PRs.
- **Story branch** (`feature/{initiativeId}-{epic-key}-{story-key}`) is where ALL task commits go.
- **Story chaining:** Story 1 branches from the epic. Story 2 branches from story 1. Story 3 branches from story 2. This allows continuous development without waiting for PR merges.
- Before each `git commit`, verify `git branch --show-current` returns the story branch.
- If on the epic branch, `git checkout {story-branch}` before committing.
- The **epic PR** targets the **initiative branch** (`feature/{initiativeId}`), NOT develop/main/master directly.
- The **initiative PR** (optional, post-epic) targets the **resolved integration branch** (whichever of develop/main/master actually exists).
