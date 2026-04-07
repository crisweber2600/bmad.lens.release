---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start PrePlan phase — brainstorm, research, and product brief"
---

# /preplan Prompt

Route to the preplan phase workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `preplan`:
   - Validate no predecessor phase required (preplan is the first phase)
   - Check current track includes `preplan` in its phases
   - Work proceeds on the initiative root branch (within techplan milestone); milestone branch is created lazily at promotion per lifecycle.yaml
4. Execute `workflows/router/preplan/workflow.md`
