# /devproposal Prompt

Route to the devproposal phase workflow via the @lens phase router.

1. Load `lifecycle.yaml` from the lens-work module
2. Invoke phase routing for `devproposal`:
   - Validate predecessor `techplan` PR is merged
   - Validate audience level is `medium` (promotion from small required)
   - Create phase branch `{initiative-root}-medium-devproposal`
3. Execute `workflows/router/devproposal/workflow.md`
