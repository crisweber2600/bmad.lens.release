---
name: 'step-03-sprint-planning'
description: 'Run the scrum-master sprint planning workflow and generate the sprint backlog'
nextStepFile: './step-04-dev-story.md'
workflowXml: '{project-root}/lens.core/_bmad/core/tasks/workflow.yaml'
scrumMasterAgent: '{project-root}/lens.core/_bmad/bmm/agents/sm.md'
sprintPlanningWorkflow: '{project-root}/lens.core/_bmad/bmm/workflows/4-implementation/sprint-planning/workflow.yaml'
---

# Step 3: Sprint Planning

## STEP GOAL:

Execute the sprint-planning sub-workflow as Bob, producing the sprint backlog after all gates pass.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Execute the sprint-planning workflow sequentially.
- Preserve SprintPlan context while using Bob’s planning persona.

### Role Reinforcement:
- You are the LENS control-plane router.
- Delegate sprint planning cleanly while keeping phase gating and artifact ownership intact.

### Step-Specific Rules:
- Load `{scrumMasterAgent}` before executing the sprint-planning workflow.
- Load `{workflowXml}` and execute `{sprintPlanningWorkflow}` through the workflow engine.
- Save outputs after each sub-workflow step.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Start workflow tracking before sub-workflow execution and finish it afterward.
- Persist the created sprint backlog location for the next step.

## CONTEXT BOUNDARIES:
- Available context: readiness-approved planning artifacts, `{scrumMasterAgent}`, `{workflowXml}`, and `{sprintPlanningWorkflow}`.
- Focus: sprint backlog generation.
- Limits: do not create dev-story artifacts in this step.
- Dependencies: readiness and compliance gates must already pass.

---

## MANDATORY SEQUENCE

### 1. Run Sprint Planning Workflow

Start workflow tracking for `sprint-planning`.

Load `{scrumMasterAgent}` to adopt Bob’s persona, then load `{workflowXml}` and execute `{sprintPlanningWorkflow}` with:
- `stories = {docs_path}/stories.md`
- `output_path = {bmad_docs}`
- `constitutional_context = current constitutional context`

Finish workflow tracking after the sprint-planning workflow completes.

Display the sprint backlog output path and confirm that prioritization and capacity allocation are complete.

### 2. Auto-Proceed

Display: "**Proceeding to dev-story creation...**"

#### Menu Handling Logic:
- After sprint planning completes successfully, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Halt only if the sprint-planning workflow fails or returns incomplete output.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Bob’s sprint-planning workflow executes through the workflow engine.
- The sprint backlog is generated at `{bmad_docs}/sprint-backlog.md`.

### SYSTEM FAILURE:
- The scrum-master persona cannot be loaded.
- The sprint-planning workflow fails or does not produce the expected backlog output.

**Master Rule:** Skipping steps is FORBIDDEN.