# /sprintplan Prompt

Route to the sprintplan phase workflow via the @lens phase router.

1. Load `lifecycle.yaml` from the lens-work module
2. Invoke phase routing for `sprintplan`:
   - Validate predecessor `devproposal` PR is merged
   - Validate audience level is `large` (promotion from medium required)
   - Create phase branch `{initiative-root}-large-sprintplan`
3. Execute `workflows/router/sprintplan/workflow.md`
