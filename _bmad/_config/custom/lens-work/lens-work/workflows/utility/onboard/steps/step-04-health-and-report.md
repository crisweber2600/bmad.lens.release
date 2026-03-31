---
name: 'step-04-health-and-report'
description: 'Run onboarding health checks and render the final onboarding summary'
---

# Step 4: Health Check And Final Report

**Goal:** Verify the onboarding prerequisites are now healthy and close with the correct next-command guidance.

---

## EXECUTION SEQUENCE

### 1. Run Health Checks

```yaml
health_checks = [
  { name: "Provider auth", status: auth_status.authenticated == true ? "✅ authenticated" : "❌ failed" },
  { name: "Governance repo", status: directory_exists(governance_repo_path) ? "✅ present" : "❌ missing" },
  { name: "Repo inventory", status: file_exists("${governance_repo_path}/repo-inventory.yaml") ? "✅ present" : "❌ missing" },
  { name: "Workspace structure", status: directory_exists("_bmad-output/lens-work") ? "✅ present" : "❌ missing" }
]

cloned_count = count(clone_results where item.status == "✅ cloned")
existing_count = count(clone_results where item.status == "✅ present")
failed_count = count(clone_results where starts_with(item.status, "⚠️") or starts_with(item.status, "❌"))
```

### 2. Render Final Response

```yaml
output: |
  ✅ Onboarding complete
  ├── Provider: ${provider}
  ├── Governance repo: ${governance_repo_path}
  ├── TargetProjects bootstrap: ${cloned_count} cloned, ${existing_count} already present, ${failed_count} attention items
  └── Next: Run `/next`, `/status`, or `/new-domain`
```