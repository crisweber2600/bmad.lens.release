---
name: ado-integration
description: Azure DevOps (ADO) work item integration via MCP and CSV-based story tracking
type: include
---

# Azure DevOps Integration Reference

This document defines patterns for integrating lens-work with Azure DevOps (ADO) work items via MCP, including a CSV-based fallback for teams without an ADO MCP connection.

---

## Overview

lens-work supports two modes of ADO task tracking:

1. **ADO MCP** — Direct integration via Azure DevOps MCP server (when available)
2. **CSV Tracking** — Lightweight file-based tracking (always available, default)

The system prioritizes CSV tracking as the baseline and layers ADO MCP on top when configured.

---

## ADO MCP Tool Reference

The following MCP tools are available for ADO work item operations:

| Tool | Purpose |
|------|---------|
| `mcp_microsoft_azu_wit_create_work_item` | Create a new work item (Task, User Story, Bug, etc.) |
| `mcp_microsoft_azu_wit_update_work_item` | Update fields on an existing work item |
| `mcp_microsoft_azu_wit_get_work_item` | Retrieve a work item by ID |
| `mcp_microsoft_azu_wit_get_work_items_batch_by_ids` | Retrieve multiple work items |
| `mcp_microsoft_azu_wit_my_work_items` | List current user's work items |
| `mcp_microsoft_azu_wit_add_child_work_items` | Add child work items to a parent |
| `mcp_microsoft_azu_wit_add_work_item_comment` | Add a comment to a work item |
| `mcp_microsoft_azu_wit_link_work_item_to_pull_request` | Link a work item to a PR |

---

## ADO Status Mapping

Lens-work story statuses map to ADO work item states:

| lens-work Status | ADO State | Context |
|------------------|-----------|---------|
| `backlog` | `New` | Story identified but not yet prepared |
| `ready-for-dev` | `New` or `Approved` | Story file created, ready for implementation |
| `in-progress` | `Active` / `Committed` | Developer actively working on story |
| `review` | `Active` | Story complete, under code review |
| `done` | `Closed` / `Done` | Code review passed, story finished |

> **Note:** Exact ADO state names depend on the process template (Agile, Scrum, CMMI, Basic).
> The integration uses the most common mappings. Override in initiative config if needed.

---

## Work Item Front Matter

When ADO integration is active, story files include an `ado_work_item_id` field in their
header metadata for bi-directional linkage:

```markdown
# Story {{epic_num}}.{{story_num}}: {{story_title}}

Status: ready-for-dev
Work Item ID: {{ado_work_item_id}}
```

This ID enables:
- Quick lookup of the ADO work item from the story file
- Status sync between the story file and ADO
- Completion sync when code review marks the story as done

---

## Integration Patterns

### 1. Story Creation → ADO Work Item Creation

When `create-story` finishes and sets status to `ready-for-dev`:

```yaml
# Condition: tracker == "azure-devops" AND ADO MCP is available
if tracker == "azure-devops":
  try:
    ado_result = mcp_microsoft_azu_wit_create_work_item(
      organization: profile.ado_organization,
      project: profile.ado_project,
      type: "User Story",       # or "Task" depending on team convention
      title: "Story ${story_id}: ${story_title}",
      description: |
        ## Story ${story_id}
        
        **Initiative:** ${initiative_id}
        **Epic:** ${epic_num}
        **Story Key:** ${story_key}
        
        Planning artifacts: ${docs_path}/
        Story file: ${implementation_artifacts}/${story_key}.md
      assignedTo: "",            # Left unassigned initially
      areaPath: profile.ado_area_path || "",
      iterationPath: profile.ado_iteration_path || "",
      parentId: initiative.tracker_id || null   # Link to parent if tracker_id exists
    )
    ado_work_item_id = ado_result.id
    # Write ado_work_item_id into story front matter
  catch:
    warn: "ADO MCP sync failed during story creation. Story created locally without ADO linkage."
    ado_work_item_id = ""
```

### 2. Dev-Story Start → ADO Status: Active

When `dev-story` sets status to `in-progress`:

```yaml
if tracker == "azure-devops" AND ado_work_item_id is not empty:
  try:
    mcp_microsoft_azu_wit_update_work_item(
      organization: profile.ado_organization,
      project: profile.ado_project,
      id: ado_work_item_id,
      state: "Active"
    )
  catch:
    warn: "ADO status sync failed (in-progress). Continue local development."
```

### 3. Code Review Pass → ADO Status: Done/Closed

When `code-review` sets status to `done`:

```yaml
if tracker == "azure-devops" AND ado_work_item_id is not empty:
  try:
    mcp_microsoft_azu_wit_update_work_item(
      organization: profile.ado_organization,
      project: profile.ado_project,
      id: ado_work_item_id,
      state: "Closed"
    )
    # Optionally add completion comment
    mcp_microsoft_azu_wit_add_work_item_comment(
      organization: profile.ado_organization,
      project: profile.ado_project,
      id: ado_work_item_id,
      text: "Story completed via BMAD lens-work. PR: ${story_pr_url}"
    )
  catch:
    warn: "ADO status sync failed (done). Update ADO manually."
```

### 4. PR Linking

> **Note:** PR linking via ADO MCP is not yet implemented in the `dev-story` workflow. The pattern below is provided for reference and future implementation.

When `dev-story` creates a PR, optionally link it to the ADO work item:

```yaml
if tracker == "azure-devops" AND ado_work_item_id is not empty AND story_pr_url:
  try:
    mcp_microsoft_azu_wit_link_work_item_to_pull_request(
      organization: profile.ado_organization,
      project: profile.ado_project,
      workItemId: ado_work_item_id,
      pullRequestUrl: story_pr_url
    )
  catch:
    warn: "ADO PR link failed. Link manually if needed."
```

---

## Profile Configuration

ADO integration requires the following fields in `profile.yaml` (set during onboarding):

```yaml
tracker: azure-devops
ado_organization: "my-org"        # ADO organization name
ado_project: "my-project"        # ADO project name
ado_area_path: ""                # Optional: area path for work items
ado_iteration_path: ""           # Optional: iteration path for sprint mapping
```

---

## Initiative Config Fields

When tracker is `azure-devops`, the initiative config stores:

```yaml
tracker_id: "12345"              # Parent ADO work item ID (optional, feature-layer)
```

This `tracker_id` serves as:
- The parent work item for child story work items
- Part of the initiative ID (e.g., `12345-rate-limiting`)

---

## Story CSV Fields (Extended)

When ADO integration is active, the CSV tracker includes an additional column:

```csv
id,title,epic,status,points,assignee,sprint,priority,phase,ado_work_item_id,created_at,updated_at
S-001,Set up API gateway,E-01,in_progress,3,alice,sprint-1,high,devproposal,54321,2026-02-01T10:00:00Z,2026-02-04T09:15:00Z
```

---

## Non-Blocking Sync Policy

All ADO MCP calls are **non-blocking**:
- If ADO MCP is unavailable or a call fails, the workflow continues
- Warnings are emitted but do not halt story creation, development, or completion
- The local story file and CSV tracker remain the source of truth
- ADO is a downstream sync target, not a gate

---

## Related Includes

- **jira-integration.md** — JIRA tracker integration (alternative tracker)
- **artifact-validator.md** — Validates story artifacts before phase gates
- **gate-event-template.md** — Gate events triggered by story completion
- **docs-path.md** — Canonical paths for story and epic files

---

## Context Enhancement Compatibility

ADO integration uses initiative metadata from config, not from planning artifact paths.
No path changes required for ADO sync. The initiative config's `docs.path` field is
available for ADO work item descriptions if link-back to artifacts is desired.

### Using docs.path in ADO Descriptions

When creating ADO work items, the `docs.path` from initiative config can be included
in work item descriptions to link back to the source planning artifacts:

```yaml
# Example: Including docs.path in ADO work item description
description: |
  Planning artifacts: ${initiative.docs.path}/
  Architecture: ${initiative.docs.path}/architecture.md
  Stories: ${initiative.docs.path}/stories.md
```

### CSV Tracker Path Compatibility

The CSV story tracker location follows the same path resolution as other artifacts:
- **New**: `${docs_path}/stories.csv` and `${docs_path}/epics.csv`
- **Legacy**: `_bmad-output/planning-artifacts/{initiative_id}/stories.csv`

Both locations are supported. The artifact validator handles path resolution transparently.
