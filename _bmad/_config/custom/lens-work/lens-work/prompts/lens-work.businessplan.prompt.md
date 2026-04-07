---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start BusinessPlan phase — PRD creation and UX design"
---

# /businessplan Prompt

Route to the businessplan phase workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `businessplan`:
   - Validate predecessor `preplan` phase is complete
   - Check current track includes `businessplan` in its phases
   - Work proceeds on the initiative root branch (within techplan milestone); milestone branch is created lazily at promotion per lifecycle.yaml
4. Execute `workflows/router/businessplan/workflow.md`
