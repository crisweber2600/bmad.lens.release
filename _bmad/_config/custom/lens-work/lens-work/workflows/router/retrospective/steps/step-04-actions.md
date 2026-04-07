---
name: 'step-04-actions'
description: 'Create actionable items from root causes — optionally as GitHub issues'
nextStepFile: null
---

# Step 4: Action Items (Optional)

**Goal:** Convert root causes into actionable improvements. Optionally create GitHub issues to track them.

---

## EXECUTION SEQUENCE

### 1. Generate Action Items

```yaml
action_items = []
for each root_cause in session.root_causes:
  action_items.push({
    title: root_cause.action,
    priority: root_cause.priority,
    category: root_cause.category,
    root_cause: root_cause.root_cause,
    effort: estimate_effort(root_cause),  # small, medium, large
    type: classify_action(root_cause)     # process-change, tooling, documentation, governance-update
  })
```

### 2. Present Action Items For Review

```
🎯 Proposed Action Items
━━━━━━━━━━━━━━━━━━━━━━━

{for each item, numbered}
  ${i}. [${item.priority}] ${item.title}
     Category: ${item.category} | Effort: ${item.effort} | Type: ${item.type}
{end for}

Options:
  1. Accept all and append to retrospective report
  2. Select specific items to keep
  3. Create GitHub issues for selected items
  4. Skip action items
```

### 3. Append Action Items To Report

```yaml
# Append the accepted action items to the retrospective report
action_items_markdown = format_action_items_table(accepted_items)

append_to_file("${session.docs_path}/retrospective-report.md", action_items_markdown)

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${session.docs_path}/retrospective-report.md
  phase: "RETRO:ACTIONS"
  initiative: ${session.initiative_root}
  description: "retrospective action items added"
```

### 4. Create GitHub Issues (If Requested)

```yaml
if user_chose_github_issues:
  for each item in selected_items:
    # Use MCP GitHub tools if available
    invoke: mcp_github_create_issue (if available)
    params:
      title: "[Retro] ${item.title}"
      body: |
        **Source:** Retrospective for ${session.initiative_root}
        **Root Cause:** ${item.root_cause}
        **Category:** ${item.category}
        **Priority:** ${item.priority}
        **Effort:** ${item.effort}
      labels: ["retrospective", "process-improvement"]

  # If MCP not available, output issue creation commands
  else:
    output_manual_issue_instructions(selected_items)
```

### 5. Curate Insights (v3.4)

Write pattern data to user insights for future planning risk awareness.

```yaml
# Invoke the retrospective skill's update-insights operation
governance_path = session.governance_repo_path || ""
if governance_path != "":
  username = invoke: git-state.current-user
  insights_path = "${governance_path}/users/${username}/insights.md"

  invoke: bmad-lens-retrospective.update-insights
  params:
    feature: ${session.initiative_root}
    problems_data: ${session.analysis_result}
    insights_path: ${insights_path}

  output: "📝 Insights updated at ${insights_path}"
```

### 6. Final Summary

```
✅ Retrospective Complete
━━━━━━━━━━━━━━━━━━━━━━━━
Initiative:    ${session.initiative_root}
Health Score:  ${session.health_score.overall}
Report:        ${session.docs_path}/retrospective-report.md
Action Items:  ${accepted_items.length} recorded
GitHub Issues: ${github_issues_created || "none"}

The retrospective is complete. Use the findings to improve
your next initiative. Key recommendations:

${top_3_recommendations}
```

---

## WORKFLOW COMPLETE

This is the final step in the retrospective workflow. No further steps.
