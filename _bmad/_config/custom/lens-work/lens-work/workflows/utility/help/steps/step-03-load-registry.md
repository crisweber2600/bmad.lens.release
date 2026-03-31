---
name: 'step-03-load-registry'
description: 'Load the canonical command registry and prepare grouped help output'
nextStepFile: './step-04-render-help.md'
---

# Step 3: Load Command Registry

**Goal:** Read the canonical `module-help.csv` file and normalize it into grouped command data for rendering and command recovery.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Treat `module-help.csv` as the authoritative command registry.
- Limit recovery matching to exact, prefix, and normalized command comparisons.

### 1. Read And Normalize The Registry

```yaml
command_rows = read_csv(command_registry_path)

if command_rows == null or command_rows.length == 0:
  FAIL("❌ module-help.csv is empty or unavailable. /help cannot render without the canonical registry.")

for row in command_rows:
  if row["workflow-file"] starts_with "workflows/router/" and row.phase starts_with "phase-":
    row.render_group = "lifecycle"
  else if row["workflow-file"] contains "router/init-initiative" or row.code in ["SW", "ST", "NX", "DS"]:
    row.render_group = "navigation"
  else if row["workflow-file"] starts_with "workflows/core/" or row["workflow-file"] starts_with "workflows/governance/":
    row.render_group = "governance"
  else:
    row.render_group = "utility"

grouped_commands = group_by(command_rows, "render_group")

for row in command_rows:
  row.user_command = "/" + slugify(row.name)

known_commands = map(command_rows, row -> row.user_command)

closest_match = null
suggested_group = null
requested_command_found = false

if requested_command != null and requested_command != "":
  closest_match = first(known_commands where item == requested_command)
  requested_command_found = closest_match != null
  if closest_match == null:
    prefix_matches = filter(known_commands, item -> starts_with(item, requested_command) or starts_with(requested_command, item))
    if prefix_matches.length > 0:
      closest_match = prefix_matches[0]
  if closest_match == null:
    normalized_request = replace(replace(requested_command, "-", ""), "/", "")
    normalized_matches = filter(known_commands, item -> replace(replace(item, "-", ""), "/", "") == normalized_request)
    if normalized_matches.length > 0:
      closest_match = normalized_matches[0]
  if closest_match != null:
    suggested_group = first(command_rows where user_command == closest_match).render_group

output: |
  ✅ Command registry loaded
  ├── Commands: ${command_rows.length}
  ├── Render groups: ${keys(grouped_commands).join(", ")}
  └── Recovery suggestion: ${closest_match != null ? closest_match : "none"}
```

### 2. Matching Strategy

Use the following resolution order when `requested_command` is present:

1. Exact command match
2. Exact prefix match
3. Normalized command match with punctuation removed
4. Render-group suggestion when no close command is available

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`

## SUCCESS CRITERIA

- The canonical command registry loads successfully.
- Each command is assigned a stable render group and user command.
- Recovery suggestions never claim fuzzy matching that the workflow does not implement.