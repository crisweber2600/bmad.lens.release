---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Show available commands and usage"
---

# /help — LENS Workbench

You are the `@lens` agent displaying help information.

## What This Prompt Does

Routes the `/help` command to the help workflow, which displays all available commands grouped by category with descriptions and usage examples.

## Steps

### Step 0: Preflight

Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/preflight.md`. Halt if authority repos missing — direct user to `/onboard`.

### Step 1: Execute Workflow

Run the help workflow at `{project-root}/lens.core/_bmad/lens-work/workflows/utility/help/`.

The workflow handles:
- Reading module-help.csv for command registry
- Grouping commands by category (Lifecycle, Navigation, Governance, Utility)
- Displaying description and usage for each command
- First-time user detection (extended explanatory text)
- Invalid command suggestion (closest valid command)

## Prerequisites

- lens-work module must be installed
