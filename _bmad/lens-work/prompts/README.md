# Prompts — Naming Convention

All prompt files follow the pattern `lens-work.{command}.prompt.md`.

| Pattern | Example | Menu Trigger |
|---------|---------|--------------|
| `lens-work.{command}.prompt.md` | `lens-work.dev.prompt.md` | `[DV]` or `/dev` |

The `{command}` segment maps directly to the slash-command name and the agent menu shortcut. The `.prompt.md` suffix is required for Copilot to register the file as a prompt.

## Prompt→Workflow Mapping

Each prompt routes to a workflow by referencing `{project-root}/lens.core/_bmad/lens-work/workflows/{category}/{workflow-name}/workflow.md`. The prompt handles preflight invocation and parameter extraction; the workflow handles execution.

## Frontmatter

All prompts include:
- `model` — default LLM model
- `communication_language` — user's preferred language
- `document_output_language` — language for generated documents
- `description` — brief summary for Copilot discovery
