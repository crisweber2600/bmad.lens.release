---
name: 'step-02-query-prs'
description: 'Query PR status for all promotion branches of target initiatives'
nextStepFile: './step-03-render-report.md'
---

# Step 2: Query PR Status

**Goal:** For each target initiative, find all open PRs that are part of the promotion lifecycle and collect their approval state.

---

## EXECUTION SEQUENCE

### 1. Identify Promotion PRs

For each `root` in `target_roots`:

```yaml
lifecycle = load: "{release_repo_root}/lens.core/_bmad/lens-work/lifecycle.yaml"
milestones = lifecycle.milestones | keys

for milestone in milestones:
  head_branch = "{root}-{milestone}"
  # Check if branch exists
  branch_exists = invoke_command("git branch --list '{head_branch}'") != ""
  if not branch_exists: continue

  # Find open PRs where head matches this branch
  pr_info = invoke: git-orchestration.query-pr-status
    head: head_branch

  if pr_info != null and pr_info.state == "open":
    pr_entries.append({
      initiative: root,
      milestone: milestone,
      pr_number: pr_info.number,
      pr_title: pr_info.title,
      pr_url: pr_info.url,
      state: pr_info.state,
      reviewers: pr_info.reviewers || [],
      approved_by: pr_info.approved_by || [],
      checks_passed: pr_info.checks_passed,
      checks_total: pr_info.checks_total,
      mergeable: pr_info.mergeable,
      review_decision: pr_info.review_decision,
      created_at: pr_info.created_at,
      updated_at: pr_info.updated_at
    })
```

### 2. Classify Blocking State

```yaml
for entry in pr_entries:
  if entry.review_decision == "APPROVED" and entry.mergeable:
    entry.blocking = "none"
    entry.action = "Ready to merge"
  elif entry.review_decision == "CHANGES_REQUESTED":
    entry.blocking = "review"
    entry.action = "Address review feedback"
  elif entry.checks_passed < entry.checks_total:
    entry.blocking = "checks"
    entry.action = "Wait for CI checks"
  elif len(entry.reviewers) == 0:
    entry.blocking = "unassigned"
    entry.action = "Assign reviewers"
  else:
    entry.blocking = "pending"
    entry.action = "Awaiting review"
```

---

## OUTPUT CONTRACT

```yaml
output:
  pr_entries: list  # enriched PR entries with blocking state
```

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
