---
name: 'step-03-create-phase-pr'
description: 'Generate the phase PR body, create the PR, and report promotion readiness'
nextStepFile: './step-04-cleanup.md'
promotionCheckInclude: '../../../includes/promotion-check.md'
createPrScript: '../../../../scripts/create-pr.ps1'
---

# Step 3: Create The Phase PR

**Goal:** Build the PR title and body from the completed artifacts, create the PR, and surface promotion readiness when the lifecycle contract requires it.

---

## EXECUTION SEQUENCE

### 1. Build The PR Payload

```yaml
pr_title = "[PHASE] ${initiative_root} - ${display_name} complete"
artifact_lines = []
for artifact in required_artifacts:
  artifact_lines.append("- [x] `${artifact}`")

pr_body = |
  ## Phase Completion: ${display_name}

  **Initiative:** ${initiative_root}
  **Audience:** ${audience}
  **Phase Agent:** ${lifecycle.phases[phase_name].agent} (${lifecycle.phases[phase_name].agent_role})

  ### Artifacts Produced
  ${artifact_lines.join("\n")}

  ### Review Instructions
  Review the committed artifacts for completeness, quality, and alignment with the lifecycle contract.
  Merge this PR to mark the ${display_name} phase as complete.

pr_result = invoke: script
script: "{createPrScript}"
params:
  SourceBranch: ${phase_branch}
  TargetBranch: ${audience_branch}
  Title: ${pr_title}
  Body: ${pr_body}

pr_url = pr_result.pr_url || pr_result.url || pr_result.Url || null
pr_already_exists = pr_result.existing == true || pr_result.Existing == true

if pr_result == null or pr_url == null:
  FAIL("❌ PR creation failed. Check provider authentication with /onboard.")

if lifecycle.phases[phase_name].auto_advance_promote == true:
  invoke: include
  path: "{promotionCheckInclude}"
  params:
    current_phase: ${phase_name}
    initiative_root: ${initiative_root}
    current_audience: ${audience}
    lifecycle_contract: ${lifecycle}

output: |
  ✅ Phase PR ready
  ├── Title: ${pr_title}
  ├── URL: ${pr_url}
  ├── Status: ${pr_already_exists ? "Already open" : "Created"}
  └── Review required: Yes

  Merge this PR to complete the ${display_name} phase.
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`