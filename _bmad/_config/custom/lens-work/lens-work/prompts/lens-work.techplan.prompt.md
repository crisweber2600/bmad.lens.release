---
model: Claude Sonnet 4.6 (copilot)
---

# /techplan Prompt

Route to the techplan phase workflow via the @lens phase router.

1. Run preflight before routing:
   1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
   2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `techplan`:
   - Validate predecessor `businessplan` PR is merged
   - Check current track includes `techplan` in its phases
   - Create phase branch `{initiative-root}-small-techplan`
4. Execute `workflows/router/techplan/workflow.md`
