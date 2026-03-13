---
model: Claude Sonnet 4.6 (copilot)
---

# /sprintplan Prompt

Route to the sprintplan phase workflow via the @lens phase router.

1. Run preflight before routing:
   1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
   2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `sprintplan`:
   - Validate predecessor `devproposal` PR is merged
   - Validate audience level is `large` (promotion from medium required)
   - Create phase branch `{initiative-root}-large-sprintplan`
4. Execute `workflows/router/sprintplan/workflow.md`
