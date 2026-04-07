---
model: "{default_model}"
communication_language: "{communication_language}"
document_output_language: "{document_output_language}"
description: "Move a feature to a different domain or service"
---

# /move-feature Prompt

Reclassify a feature initiative to a different domain and/or service.

## Prerequisites

- An active feature-scope initiative must exist (run `/new-feature` first)
- Working tree must be clean (uncommitted changes will block the move)

## Steps

1. Run preflight to identify the active initiative
2. Execute `workflows/utility/move-feature/workflow.md`

## Side Effects

- Initiative branches are renamed to reflect the new domain/service
- Initiative config (`initiative.yaml`) is moved to the new path
- Governance inventory is updated

## Error Conditions

| Condition | Response |
|-----------|----------|
| No active initiative | `❌ No active initiative. Use /new-feature first.` |
| Initiative is not feature-scope | `❌ Only feature-scope initiatives can be moved.` |
| Target domain/service already has a feature with same name | `❌ Feature name conflict at target location.` |
