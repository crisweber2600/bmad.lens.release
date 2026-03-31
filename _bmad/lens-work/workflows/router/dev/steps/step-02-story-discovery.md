---
name: 'step-02-story-discovery'
description: 'Handle batch-mode requests and discover the ordered story set for the target epic'
nextStepFile: './step-03-story-loop.md'
---

# Step 2: Batch Mode And Story Discovery

## STEP GOAL:

Handle question-only batch mode when requested, then resolve and confirm the ordered story set for the epic being implemented.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Carry forward state from preflight without resetting it.
- Fail fast when the requested epic has no executable story files.

### Role Reinforcement:
- You are the LENS control-plane router.
- Keep the implementation loop ordered, explicit, and reviewable.

### Step-Specific Rules:
- Preserve the existing batch-mode exit behavior.
- Discover stories from initiative-scoped docs before generic implementation artifacts.
- Do not enter the story loop until the user explicitly accepts the discovered set.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Persist `session.special_instructions`, `session.epic_number`, `session.story_files`, `session.stories_completed`, and `session.stories_failed` before continuing.
- Sort and deduplicate the discovered story set before presenting it.

## CONTEXT BOUNDARIES:
- Available context: `initiative`, `bmad_docs`, implementation artifacts, input `epic_number`, and optional `special_instructions`.
- Focus: batch handling, story discovery, ordering, and user confirmation.
- Limits: do not implement any story in this step.
- Dependencies: successful preflight and a valid epic number.

---

## MANDATORY SEQUENCE

### 1. Batch Mode (Single-File Questions)

If `initiative.question_mode == "batch"`, run the existing `lens-work.batch-process` flow for phase `dev`, generate `dev-implementation-questions.md`, and stop the workflow after the batch artifact is produced.

### 2. Epic Story Discovery

Read `params.epic_number` and optional `params.special_instructions`. Persist the special instructions into `session.special_instructions` so they can be applied to every story.

Discover candidate story files in this order:
- `{bmad_docs}/dev-story-{epic_number}-*.md`
- `{bmad_docs}/*epic-{epic_number}*.md`
- `_bmad-output/implementation-artifacts/dev-story-{epic_number}-*.md`
- `_bmad-output/implementation-artifacts/*epic-{epic_number}*.md`

Deduplicate the results by story id, sort them into implementation order, and fail with the existing guidance if no story files are found.

Present the discovered story set, including special instructions when present.

### 3. Confirm The Story Set

Display: "**Select:** [C] Continue with the discovered stories [X] Stop"

#### Menu Handling Logic:
- IF C: Persist `session.epic_number`, `session.story_files`, `session.stories_completed = []`, and `session.stories_failed = []`, then load, read fully, and execute `{nextStepFile}`.
- IF X: Stop the workflow without modifying story execution state.
- IF any other response: clarify the story set or special instructions, then redisplay this menu.

#### EXECUTION RULES:
- ALWAYS halt and wait for user input after presenting the story-set menu.
- ONLY proceed when the user selects `C`.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Batch mode exits cleanly when requested.
- A non-empty, ordered story set is discovered for the requested epic.
- The user explicitly accepts the story set before story execution begins.

### SYSTEM FAILURE:
- No dev-story artifacts exist for the requested epic.
- Story discovery cannot produce an ordered, deduplicated set.
- The user declines to proceed.

**Master Rule:** Skipping steps is FORBIDDEN.