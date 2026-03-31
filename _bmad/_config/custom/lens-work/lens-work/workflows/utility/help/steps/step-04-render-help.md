---
name: 'step-04-render-help'
description: 'Render grouped help output and command recovery guidance'
---

# Step 4: Render Help Output

**Goal:** Present the authoritative command reference in a discoverable format, with recovery guidance when the user entered an invalid or partial command.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Render only the grouped registry rows prepared in the previous step.
- Keep recovery guidance authoritative and concise.

### 1. Render The Command Reference

```yaml
help_sections = []

for group_name in ["lifecycle", "navigation", "governance", "utility"]:
  rows = grouped_commands[group_name] || []
  if rows.length > 0:
    rendered_rows = map(rows, row -> "- " + row.user_command + " — " + row.description)
    help_sections.append(group_name.toUpperCase() + "\n" + rendered_rows.join("\n"))

output: |
  📖 @lens Command Reference

  ${help_sections.join("\n\n")}
```

### 2. Render Invalid-Command Recovery When Needed

```yaml
if requested_command != null and requested_command != "" and requested_command_found != true:
  if closest_match != null:
    output: |
      ❓ Unknown command: `${requested_command}`
      ├── Did you mean `${closest_match}`?
      └── Group: ${suggested_group}
  else:
    output: |
      ❓ Unknown command: `${requested_command}`
      ├── No close command match found
      └── Use `/help` to browse the full command set
```

### 3. Close With The Default Guidance

```yaml
output: |
  💡 Tip: Run `/next` anytime to see the recommended next action.
```

## SUCCESS CRITERIA

- The command reference is grouped in a stable order.
- Invalid-command recovery appears only when a command was supplied.
- The closing guidance points users to `/next` for workflow continuation.