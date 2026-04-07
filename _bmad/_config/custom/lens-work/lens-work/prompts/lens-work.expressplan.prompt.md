---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start ExpressPlan — all planning artifacts in one session, no branches, no PRs"
---

# /expressplan Prompt

Route to the expressplan workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Validate that the active initiative uses the `express` track
4. Execute `workflows/router/expressplan/workflow.md`
