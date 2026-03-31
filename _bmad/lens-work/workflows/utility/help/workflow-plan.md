# Workflow Plan: help

## Goal

Display the authoritative `@lens` command reference while adapting the response for first-time users and invalid command lookups.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Resolve profile and registry paths
   - Normalize the requested command input
2. `steps/step-02-detect-context.md`
   - Detect whether the user is new or returning
   - Decide whether the workflow is rendering general help or command recovery
3. `steps/step-03-load-registry.md`
   - Read `module-help.csv`
   - Normalize rows for grouped rendering and lookup
4. `steps/step-04-render-help.md`
   - Render the grouped command reference
   - Suggest the closest valid command when appropriate
   - End with the `/next` guidance footer

## Key State

- `requested_command`
- `profile_path`
- `first_time_user`
- `command_registry_path`
- `command_rows`
- `grouped_commands`
- `closest_match`
- `suggested_group`

## Output Artifacts

- None. This workflow renders chat output from the canonical registry.