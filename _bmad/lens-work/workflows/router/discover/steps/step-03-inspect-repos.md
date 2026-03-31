---
name: 'step-03-inspect-repos'
description: 'Inspect each discovered repo for BMAD configuration and primary language'
nextStepFile: './step-04-governance-and-branches.md'
---

# Step 3: Inspect The Discovered Repositories

**Goal:** Build the per-repo discovery result set, keeping inspection failures isolated to the repo that failed.

---

## EXECUTION SEQUENCE

### 1. Inspect Repo State

```yaml
repo_results = []

for repo in discovered_repos:
  has_bmad = directory_exists("${repo.path}/.bmad")
  language = "unknown"

  if file_exists("${repo.path}/.bmad/language"):
    language = trim(read("${repo.path}/.bmad/language"))
  else if file_exists("${repo.path}/package.json"):
    language = file_exists("${repo.path}/tsconfig.json") ? "typescript" : "javascript"
  else if file_exists("${repo.path}/pyproject.toml") or file_exists("${repo.path}/requirements.txt"):
    language = "python"
  else if file_exists("${repo.path}/go.mod"):
    language = "go"
  else if file_exists("${repo.path}/pom.yaml") or file_exists("${repo.path}/build.gradle"):
    language = "java"

  repo_results.append({
    repo_name: repo.repo_name,
    path: repo.path,
    checkout_branch: repo.checkout_branch,
    has_bmad: has_bmad,
    language: language,
    governance_status: "pending",
    branch_status: "pending",
    context_status: "pending",
    documentation_status: "pending"
  })

output: |
  ✅ Repo inspection complete
  ├── Repos discovered: ${repo_results.length}
  └── BMAD configured: ${count(repo_results where item.has_bmad == true)}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`