---
name: 'step-04-dev-story'
description: 'Batch-create dev-ready story artifacts for all stories in the sprint backlog for the target epic'
nextStepFile: './step-05-closeout.md'
workflowXml: '{project-root}/lens.core/_bmad/core/tasks/workflow.yaml'
scrumMasterAgent: '{project-root}/lens.core/_bmad/bmm/agents/sm.md'
devStoryWorkflow: '{project-root}/lens.core/_bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml'
---

# Step 4: Batch-Create Dev-Ready Stories

## STEP GOAL:

Generate developer-facing story artifacts for ALL stories in the sprint backlog for the target epic, so `/dev` can discover and implement the complete story set in a single session.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Iterate ALL stories in the sprint backlog for the target epic — do not stop after one.
- Preserve constitutional context while generating each dev-story artifact.

### Role Reinforcement:
- You are the LENS control-plane router.
- Convert SprintPlan output into a complete set of developer-ready handoffs without losing traceability.

### Step-Specific Rules:
- Load `{scrumMasterAgent}` before executing `{devStoryWorkflow}`.
- Load `{workflowXml}` and execute `{devStoryWorkflow}` through the workflow engine once per story.
- Generate each story artifact in `{bmad_docs}` so `/dev` can consume them directly.
- Skip stories that already have existing dev-story artifacts (no overwrite).

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Track created count and skipped count for closeout reporting.
- Persist all created story ids and output paths for closeout.

## CONTEXT BOUNDARIES:
- Available context: sprint backlog, `{workflowXml}`, `{scrumMasterAgent}`, and `{devStoryWorkflow}`.
- Focus: batch dev-story generation and handoff readiness.
- Limits: do not create the milestone branch or PR in this step.
- Dependencies: successful sprint planning output with populated sprint backlog.

---

## MANDATORY SEQUENCE

### 1. Load Sprint Backlog For Target Epic

Resolve `target_epic` from session context. If not set, prompt the user to select from available epics in the sprint output.

Load the sprint backlog from `sprint-status.yaml` if available (structured); otherwise read `sprint-backlog.md` and parse epic/story assignments from the markdown.
Collect all stories assigned to the target epic into `epic_stories`.

```yaml
# Resolve target_epic: use session value if already set, otherwise prompt
if not target_epic:
  available_epics = list_files("${docs_path}").filter(f => f.startsWith("epic-"))
  target_epic = ask_user("Which epic should dev-stories be generated for? (e.g., epic-1)")

# Load structured sprint status if available; otherwise fall back to markdown
sprint_status_yaml = load_if_exists("${docs_path}/sprint-status.yaml")
if sprint_status_yaml != null:
  epic_stories = sprint_status_yaml.stories.filter(story => story.epic == target_epic)
else:
  # sprint-backlog.md is markdown — the agent must read and parse it.
  # Extract story entries (id and title) listed under the heading for target_epic.
  # Produce a list of { id, title, epic } objects into epic_stories.
  # If no stories are found for the target epic, set epic_stories = []
  backlog_text = read_file("${docs_path}/sprint-backlog.md")
  # Agent: scan backlog_text for stories assigned to target_epic and populate epic_stories
  epic_stories = []
  if epic_stories.length == 0:
    warning: "⚠️ No stories found for epic '${target_epic}' in sprint-backlog.md. Verify epic ID and backlog format."

created_count = 0
skipped_count = 0
created_stories = []
```

### 2. Iterate And Create Dev-Story Artifacts

Start workflow tracking for `dev-story-batch`.

Load `{scrumMasterAgent}` once before the loop.

For EACH story in `epic_stories`:

```yaml
for story in epic_stories:
  artifact_path = "${bmad_docs}/dev-story-${story.id}.md"

  # Skip if artifact already exists
  if file_exists(artifact_path):
    skipped_count += 1
    output: "⏭️  Skipping ${story.id} — dev-story artifact already exists at ${artifact_path}"
    continue

  # Generate dev-story artifact using the core workflow engine.
  # Load {scrumMasterAgent} (already loaded once before loop) and execute {devStoryWorkflow}
  # through the workflow engine ({workflowXml}) with the inputs below.
  # The workflow engine drives story artifact creation to artifact_path.
  # Inputs:
  #   story_id: ${story.id}
  #   story_title: ${story.title}
  #   output_path: ${bmad_docs}
  #   constitutional_context: ${constitutional_context}
  # The workflow MUST write the dev-story file to: ${artifact_path}

  created_count += 1
  created_stories.append(story.id)
  output: "✅ Created dev-story artifact: ${artifact_path} (${created_count}/${epic_stories.length})"

# Mark all created stories as ready-for-dev in sprint-status.yaml
if sprint_status_yaml != null and created_stories.length > 0:
  for story_id in created_stories:
    story_entry = sprint_status_yaml.stories.find(s => s.id == story_id)
    if story_entry:
      story_entry.status = "ready-for-dev"
  write_file("${docs_path}/sprint-status.yaml", serialize_yaml(sprint_status_yaml))
  output: "📝 Updated sprint-status.yaml: ${created_stories.length} stories marked as ready-for-dev"
```

Finish workflow tracking after all stories are processed.

Display batch summary:
```
📋 Dev-Story Batch Summary
├── Epic: ${target_epic}
├── Total stories: ${epic_stories.length}
├── Created: ${created_count}
├── Skipped (existing): ${skipped_count}
└── All created stories marked as ready-for-dev
```

### 3. Auto-Proceed

Display: "**Proceeding to closeout and handoff...**"

#### Menu Handling Logic:
- After batch dev-story generation completes, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Halt only if ALL dev-story generation attempts fail or no stories exist for the target epic.
- Individual story failures should be logged but should not block remaining stories.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Dev-story artifacts created for all stories in the sprint backlog for the target epic (minus skipped existing ones).
- Sprint status updated to mark created stories as `ready-for-dev`.
- Created and skipped counts are available for closeout reporting.

### SYSTEM FAILURE:
- No stories found in the sprint backlog for the target epic.
- ALL dev-story generation attempts fail.
- Sprint status cannot be updated.

**Master Rule:** Skipping steps is FORBIDDEN.