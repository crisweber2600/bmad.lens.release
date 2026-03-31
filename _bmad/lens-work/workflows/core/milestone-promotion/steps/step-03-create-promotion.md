---
name: 'step-03-create-promotion'
description: 'Create the next-milestone branch if needed, assemble the promotion PR body, and create the PR'
nextStepFile: './step-04-render-result.md'
createPrScript: '../../../../scripts/create-pr.ps1'
sensingReportInclude: '../../includes/sensing-report.md'
---

# Step 3: Create The Promotion PR

**Goal:** Prepare the target milestone branch and open the promotion PR with the required gate summary.

---

## EXECUTION SEQUENCE

### 1. Create Target Branch When Needed And Open The PR

```yaml
if not branch_exists(target_branch):
  invoke: git-orchestration.create-branch
  params:
    branch: ${target_branch}
    from: ${initiative_root}

promotion_pr_body = template: |
  ## Promotion Summary

  **Initiative:** ${initiative_root}
  **Promotion:** ${current_milestone} -> ${next_milestone}

  ## Gate Check Results

  All hard gates passed.

  ## Compliance Status

  ${compliance_result.summary || "No additional compliance notes."}

  ## Cross-Initiative Sensing

  ${sensing_result.summary || "No overlaps detected."}

  ## Review Requirements

  Review and merge this PR to complete the promotion.

promotion_pr = invoke: script
script: "{createPrScript}"
params:
  SourceBranch: ${source_branch}
  TargetBranch: ${target_branch}
  Title: "[PROMOTE] ${initiative_root} ${current_milestone}->${next_milestone} - Milestone Gate"
  Body: ${promotion_pr_body}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`