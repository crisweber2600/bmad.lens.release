---
name: 'step-03-story-loop'
description: 'Execute the per-story implementation loop, review gate, PR creation, and BMAD control-plane updates'
nextStepFile: './step-04-epic-completion.md'
targetRepoRoutingData: '../data/story-target-repo-routing.md'
implementationGuidanceData: '../data/story-implementation-guidance.md'
reviewLoopData: '../data/story-review-loop.md'
---

# Step 3: Story Implementation Loop

## STEP GOAL:

For each story in the epic, enforce constitutional gates, route implementation into the TargetProject repo, run review loops, and create the story PR before moving to the next story.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Process one story at a time in the resolved story order.
- Stop immediately when an enforced constitutional or review gate fails.

### Role Reinforcement:
- You are the LENS control-plane router.
- Protect the story-branch, epic-branch, and initiative-branch chain while coordinating implementation inside the TargetProject repo.

### Step-Specific Rules:
- NEVER skip the story constitution check or pre-implementation gates.
- Use `{targetRepoRoutingData}`, `{implementationGuidanceData}`, and `{reviewLoopData}` in that order for every story.
- Keep TargetProject writes inside `session.target_path` and keep control-plane state updates in the BMAD repo.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly for each story.
- Maintain `story_id`, `dev_story`, `dev_story_source`, `article_gates`, `session.story_branch`, `session.epic_branch`, and `session.stories_completed` throughout the loop.
- Do not advance to the next story until review, PR creation, and control-plane updates are complete for the current story.

## CONTEXT BOUNDARIES:
- Available context: `session.story_files`, `initiative`, `constitutional_context`, and the three referenced data files.
- Focus: story-by-story execution, gating, branch routing, implementation guidance, review, and PR creation.
- Limits: do not run the epic completion gate in this step.
- Dependencies: accepted story set from step 2 and successful preflight.

---

## MANDATORY SEQUENCE

### 1. Story Loop

Iterate `session.story_files` in order. For each story:
- derive `story_id`
- load the story artifact into `dev_story`
- persist `dev_story_source`
- present the story title, acceptance criteria, technical notes, and active `/dev` branch context before implementation begins

### 2. Story Constitution Check (Required)

Run `constitution.compliance-check` against the active story artifact.

If article-gate failures are present:
- display the failing gates
- auto-resolve and halt when enforcement mode is `enforced`
- otherwise record the advisory warning through constitutional complexity tracking

If legacy fail counts remain after compliance evaluation and enforcement mode is `enforced`, auto-resolve the gate block and halt.

### 3. Pre-Implementation Gates (Required)

Generate article gates for the active story and display the gate summary.

If any pre-implementation gate fails:
- auto-resolve and halt when enforcement mode is `enforced`
- otherwise gather the user’s justification for each override and record it through constitutional complexity tracking

Run the checklist quality gate against `bmad_docs` and `docs_path` before implementation proceeds.

### 4. Target Repo Routing, Implementation Guidance, And Review Loop

Load and apply the following references inside the active story iteration, in order:

- `{targetRepoRoutingData}` for initiative, epic, and story branch routing plus the dev write guard
- `{implementationGuidanceData}` for constitutional implementation guidance and per-task commit rules
- `{reviewLoopData}` for code review, party-mode teardown, story PR creation, and BMAD control-plane completion updates

### 5. End-Of-Loop Summary

After the final story finishes, display the completed story list and confirm how many stories were successfully implemented in the epic.

### 6. Auto-Proceed

Display: "**Proceeding to the epic completion gate...**"

#### Menu Handling Logic:
- After the story loop completes successfully, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Halt only when a story-level gate, review loop, or PR creation block remains unresolved.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Every story in `session.story_files` is processed in order.
- Story-level constitutional and pre-implementation gates are enforced.
- Target repo routing, implementation guidance, review, and PR creation all complete per story.
- `session.stories_completed` reflects the finished story set.

### SYSTEM FAILURE:
- Any story fails constitutional enforcement.
- Target repo routing or dev write guard fails.
- Code review, party-mode teardown, or story PR creation halts the loop.

**Master Rule:** Skipping steps is FORBIDDEN.