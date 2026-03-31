---
name: 'step-04-render-result'
description: 'Render the promotion result, wait for PR merge, publish artifacts to governance, and show the remaining promotion chain'
---

# Step 4: Render Promotion Result and Publish to Governance

**Goal:** Report the created promotion PR, wait for merge, publish artifacts to governance, and show the next promotion opportunities.

---

## EXECUTION SEQUENCE

### 1. Report The Promotion Result

```yaml
output: |
  ✅ Promotion PR created: ${promotion_pr.Url || promotion_pr.url || promotion_pr}

  [PROMOTE] ${initiative_root} ${current_milestone}->${next_milestone} - Milestone Gate

  The PR requires review and merge to complete promotion.
  Sensing: ${sensing_result.overlap_count || 0} overlapping initiative(s) detected.
```

### 2. Wait For PR Merge

```yaml
merge_result = invoke: git-orchestration.wait-for-pr-merge
params:
  source_branch: ${source_branch}
  target_branch: ${target_branch}
  pr_url: ${promotion_pr.Url || promotion_pr.url || promotion_pr}
  timeout_seconds: 300

if not merge_result.merged:
  output: |
    ⚠️ Promotion PR not yet merged — governance publication deferred.
    Merge the PR and run `/promote` again to trigger publication.
  STOP
```

### 3. Publish Artifacts To Governance

After the promotion PR is merged, publish all initiative artifacts to governance.

```yaml
# Load artifact list from initiative-state.yaml
state_yaml = load("initiative-state.yaml")
all_artifacts = []
for phase_key in state_yaml.artifacts:
  all_artifacts.extend(state_yaml.artifacts[phase_key])

publication_result = invoke: git-orchestration.publish-to-governance
params:
  initiative: ${initiative_root}
  domain: ${initiative_config.domain}
  service: ${initiative_config.service}
  milestone: ${next_milestone}
  artifact_list: ${all_artifacts}
```

### 4. Report Final Promotion Status

```yaml
if publication_result.status == "published":
  output: |
    ✅ Promotion complete with governance publication
    ├── PR merged: ${merge_result.merged_at}
    ├── Artifacts published to: ${publication_result.target_path}
    ├── Artifact count: ${publication_result.artifact_count}
    ├── _manifest.yaml generated: ${publication_result.manifest_generated}
    └── Promotion chain: ${current_milestone} → ${next_milestone}

else:
  output: |
    ✅ Promotion complete (governance publication skipped)
    ├── PR merged: ${merge_result.merged_at}
    ├── Publication status: ${publication_result.status}
    ├── Reason: ${publication_result.reason}
    └── Promotion chain: ${current_milestone} → ${next_milestone}

output: |
  Next available: follow the lifecycle gates for ${next_milestone}
```
```