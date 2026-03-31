---
name: 'step-04-governance-and-branches'
description: 'Update governance inventory and create control-repo helper branches'
nextStepFile: './step-05-report.md'
---

# Step 4: Governance And Branch Updates

**Goal:** Upsert discovery data into the governance inventory and create per-repo control branches without aborting the entire workflow when one repo fails.

---

## EXECUTION SEQUENCE

### 1. Update Governance Inventory

```yaml
invoke_command("git -C ${resolver_result.governance_repo_path} pull origin || true")

inventory_path = "${resolver_result.governance_repo_path}/repo-inventory.yaml"
inventory = load_if_exists(inventory_path) || { repos: [] }
inventory_entries = inventory.repos || []

for repo in repo_results:
  existing = first(inventory_entries where item.name == repo.repo_name)
  new_entry = {
    name: repo.repo_name,
    path: repo.path,
    language: repo.language,
    bmad_configured: repo.has_bmad,
    domain: resolver_result.domain,
    service: resolver_result.service,
    discovered_at: now_iso8601()
  }

  if existing != null:
    update(existing, new_entry)
  else:
    inventory_entries.append(new_entry)

  repo.governance_status = "Updated"

write_yaml(inventory_path, { repos: inventory_entries })
invoke_command("git -C ${resolver_result.governance_repo_path} add repo-inventory.yaml && git -C ${resolver_result.governance_repo_path} commit -m \"[discover] Add/update repos for ${resolver_result.domain}/${resolver_result.service}\" && git -C ${resolver_result.governance_repo_path} push origin || true")

governance_summary = {
  updated: count(repo_results where item.governance_status == "Updated")
}
```

### 2. Create Control-Repo Helper Branches

```yaml
branch_summary = { created: 0, existing: 0, failed: 0 }

for repo in repo_results:
  branch_name = "${resolver_result.initiative_root}-${resolver_result.domain}-${resolver_result.service}-${repo.repo_name}"
  if branch_exists(branch_name):
    repo.branch_status = "Exists"
    branch_summary.existing = branch_summary.existing + 1
  else:
    invoke_command("git branch ${branch_name} ${resolver_result.initiative_root} && git push origin ${branch_name} || true")
    repo.branch_status = "Created"
    branch_summary.created = branch_summary.created + 1
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`