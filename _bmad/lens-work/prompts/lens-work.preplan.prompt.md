# /preplan Prompt

Route to the preplan phase workflow via the @lens phase router.

1. Load `lifecycle.yaml` from the lens-work module
2. Invoke phase routing for `preplan`:
   - Validate no predecessor phase required (preplan is the first phase)
   - Check current track includes `preplan` in its phases
   - Create phase branch `{initiative-root}-small-preplan`
3. Execute `workflows/router/preplan/workflow.md`
