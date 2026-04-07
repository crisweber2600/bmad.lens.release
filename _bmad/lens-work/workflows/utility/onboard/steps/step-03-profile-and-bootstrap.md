---
name: 'step-03-profile-and-bootstrap'
description: 'Create the non-secret profile and bootstrap TargetProjects clones'
nextStepFile: './step-04-health-and-report.md'
profilePath: '{project-root}/_bmad-output/lens-work/personal/profile.yaml'
---

# Step 3: Profile And TargetProjects Bootstrap

**Goal:** Persist non-secret onboarding preferences and clone or verify inventory-listed repositories without writing credentials to tracked files.

---

## EXECUTION SEQUENCE

### 1. Write The User Profile

```yaml
profile_path = "{profilePath}"

profile_data = {
  role: "contributor",
  domain: null,
  provider: provider,
  batch_preferences: {
    question_mode: "guided",
    auto_checkpoint: true
  },
  target_projects_path: "TargetProjects",
  governance_repo_path: governance_repo_path,
  created: now_iso8601()
}

write_yaml(profile_path, profile_data)
```

### 1b. Create Governance User Profile (v3.4)

```yaml
# Write user profile to governance repo for cross-feature visibility
if governance_repo_path != null and governance_repo_path != "":
  username = invoke: git-state.current-user
  gov_profile_path = "${governance_repo_path}/users/${username}.md"

  if not file_exists(gov_profile_path):
    template = load("../../assets/templates/user-profile-template.md")
    rendered = template
      .replace("{username}", username)
      .replace("{provider}", provider)
      .replace("{created_date}", now_iso8601())

    ensure_directory(dirname(gov_profile_path))
    write_file(gov_profile_path, rendered)
```

### 2. Bootstrap Inventory Clones

```yaml
inventory = load("${governance_repo_path}/repo-inventory.yaml")
inventory_entries = inventory.repositories || inventory.repos || inventory
clone_results = []

for entry in inventory_entries:
  repo_name = entry.name || entry.repo || "(unnamed)"
  repo_path = entry.local_path || entry.clone_path || entry.path
  repo_remote = entry.remote_url || entry.repo_url || entry.remote || entry.url

  if repo_path == null or repo_path == "":
    clone_results.append({ repo: repo_name, path: null, action: "skip", status: "⚠️ missing path" })
  else if directory_exists("${repo_path}/.git"):
    clone_results.append({ repo: repo_name, path: repo_path, action: "verify", status: "✅ present" })
  else if repo_remote != null and repo_remote != "":
    invoke_command("git clone ${repo_remote} ${repo_path}")
    clone_results.append({ repo: repo_name, path: repo_path, action: "clone", status: "✅ cloned" })
  else:
    clone_results.append({ repo: repo_name, path: repo_path, action: "skip", status: "⚠️ missing remote" })

output: |
  ✅ Profile and bootstrap complete
  ├── Profile: ${profile_path}
  └── Inventory entries processed: ${clone_results.length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`