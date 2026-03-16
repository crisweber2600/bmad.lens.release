# Copilot Adapter — lens-work v2

This directory contains the thin VS Code Copilot adapter that wires the `@lens` agent into the IDE. It references the lens-work module by path — it never duplicates module content.

## Structure

```
.github/
├── copilot-instructions.md     # References BMAD framework + lens-work module
└── agents/
    └── lens.agent.md           # Thin wrapper → @lens agent in release module
```

## Principles

- **Thin adapter** — references only, never copies or duplicates module content
- **Path references** — skills and workflows are referenced by path to the release module
- **Auto-propagation** — changes to module skills/workflows propagate automatically
- **Domain 3** — `@lens` does NOT modify `.github/` during initiative work
- **Write frequency** — RARELY, only on module version update
