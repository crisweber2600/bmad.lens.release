---
name: 'step-02-scan-repos'
description: 'Enumerate cloned repos and sync each one to its most recent branch'
nextStepFile: './step-03-inspect-repos.md'
---

# Step 2: Scan And Sync Repositories

**Goal:** Discover the cloned repos under the target service path and normalize each repo to the most recent reachable branch before inspection continues.

---

## EXECUTION SEQUENCE

### 1. Discover And Sync Repos

```yaml
discovered_repos = []

for child_dir in list_directories(resolver_result.scan_path):
  if directory_exists("${child_dir}/.git"):
    repo_name = basename(child_dir)
    output: "✓ discovered: ${repo_name}"
    invoke_command("git -C ${child_dir} fetch --all --prune || true")
    checkout_branch = invoke_command("git -C ${child_dir} for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads refs/remotes/origin | grep -v 'origin/HEAD' | head -1")
    if checkout_branch != null and trim(checkout_branch) != "":
      invoke_command("git -C ${child_dir} checkout ${checkout_branch} || true")
    discovered_repos.append({ path: child_dir, repo_name: repo_name, checkout_branch: checkout_branch })

if discovered_repos.length == 0:
  output: |
    ℹ️ No repos found in ${resolver_result.scan_path}.
    Clone your repos there and rerun `/discover`.
  exit: 0
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`