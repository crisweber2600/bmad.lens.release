---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Start DevProposal phase — epics, stories, and readiness check"
---

# /devproposal Prompt

Route to the devproposal phase workflow via the @lens phase router.

1. **Preflight**: Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `devproposal`:
   - Validate techplan milestone promotion is complete
   - Work proceeds on the `{initiative-root}-devproposal` milestone branch (created by prior promotion)
4. Execute `workflows/router/devproposal/workflow.md`
