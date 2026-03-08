# /businessplan Prompt

Route to the businessplan phase workflow via the @lens phase router.

1. Load `lifecycle.yaml` from the lens-work module
2. Invoke phase routing for `businessplan`:
   - Validate predecessor `preplan` PR is merged
   - Check current track includes `businessplan` in its phases
   - Create phase branch `{initiative-root}-small-businessplan`
3. Execute `workflows/router/businessplan/workflow.md`
