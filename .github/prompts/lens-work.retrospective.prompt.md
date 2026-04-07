---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Run a retrospective on an initiative — review what worked, what broke, and capture lessons"
---

# /retrospective Prompt

Route to the retrospective workflow via the @lens router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Execute `workflows/router/retrospective/workflow.md`
