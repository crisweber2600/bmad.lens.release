---
---

# /devproposal Prompt

Route to the devproposal phase workflow via the @lens phase router.

1. Run preflight before routing:
   1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
   2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `devproposal`:
   - Validate predecessor `techplan` PR is merged
   - Validate audience level is `medium` (promotion from small required)
   - Create phase branch `{initiative-root}-medium-devproposal`
4. Execute `workflows/router/devproposal/workflow.md`
