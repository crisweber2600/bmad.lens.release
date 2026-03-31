---
name: help
description: Display the canonical @lens command reference with first-use onboarding and invalid-command recovery
agent: "@lens"
trigger: /help command
category: utility
phase_name: utility
display_name: Help
entryStep: './steps/step-01-preflight.md'
inputs:
  requested_command:
    description: Optional invalid or partial command to resolve while rendering help
    required: false
    default: ""
---

# /help - Command Reference Workflow

**Goal:** Render the canonical @lens command registry with enough context for first-time users and enough recovery guidance for invalid command attempts.

**Your Role:** Act as the LENS command guide. Confirm the environment is valid, detect whether the user needs onboarding context, then present the authoritative command list with helpful recovery suggestions.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Each step owns one concern: preflight, user context, registry loading, and response rendering.
- State persists through `requested_command`, `profile_path`, `first_time_user`, `command_registry_path`, `command_rows`, `grouped_commands`, `closest_match`, and `suggested_group`.
- The command list comes from `module-help.csv` so `/help` stays aligned with the installed module surface.

---

## INITIALIZATION

### Configuration Loading

Load the lens-work session context already provided by `@lens` and resolve:

- `{user_name}`
- `{communication_language}`
- `{output_folder}`
- `{initiative_output_folder}`
- `{personal_output_folder}`

### Workflow References

- `preflight_include = ../../includes/preflight.md`
- `command_registry = ../../../module-help.csv`

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-preflight.md` - Preflight and help-context initialization
2. `step-02-detect-context.md` - Detect first-time-user state and request intent
3. `step-03-load-registry.md` - Load and normalize the canonical command registry
4. `step-04-render-help.md` - Render grouped help output, invalid-command recovery, and footer
