---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start TechPlan phase — architecture and technical decisions"
---

# /techplan Prompt

Route to the techplan phase workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `techplan`:
   - Validate predecessor `businessplan` phase is complete
   - Check current track includes `techplan` in its phases
   - Work proceeds on the initiative root branch (within techplan milestone); auto_advance_promote creates devproposal milestone branch at closeout
4. Execute `workflows/router/techplan/workflow.md`
