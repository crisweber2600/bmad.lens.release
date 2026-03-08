# /techplan Prompt

Route to the techplan phase workflow via the @lens phase router.

1. Load `lifecycle.yaml` from the lens-work module
2. Invoke phase routing for `techplan`:
   - Validate predecessor `businessplan` PR is merged
   - Check current track includes `techplan` in its phases
   - Create phase branch `{initiative-root}-small-techplan`
3. Execute `workflows/router/techplan/workflow.md`
