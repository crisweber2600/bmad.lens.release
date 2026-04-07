---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start SprintPlan phase — sprint status and story file generation"
---

# /sprintplan Prompt

Route to the sprintplan phase workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `sprintplan`:
   - Validate devproposal milestone promotion is complete
   - Work proceeds on the `{initiative-root}-sprintplan` milestone branch (created by prior promotion)
4. Execute `workflows/router/sprintplan/workflow.md`
