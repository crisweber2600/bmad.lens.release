# Copilot Adapter: copilot-instructions.md Template

This is the template for the `.github/copilot-instructions.md` file that gets installed into control repos by the `setupRepo` prompt.

---

```markdown
<!-- LENS-WORK ADAPTER -->
# LENS Workbench — Copilot Instructions

## Module Reference

This control repo uses the LENS Workbench module from the release payload:

- **Module path:** `bmad.lens.release/_bmad/lens-work/`
- **Lifecycle contract:** `bmad.lens.release/_bmad/lens-work/lifecycle.yaml`
- **Module version:** See `bmad.lens.release/_bmad/lens-work/module.yaml`

## Agent

The `@lens` agent is defined at `.github/agents/bmad-agent-lens-work-lens.agent.md` and references
the module agent at `bmad.lens.release/_bmad/lens-work/agents/lens.agent.md`.

## Skills (by path reference)

| Skill | Path |
|-------|------|
| git-state | `bmad.lens.release/_bmad/lens-work/skills/git-state.md` |
| git-orchestration | `bmad.lens.release/_bmad/lens-work/skills/git-orchestration.md` |
| constitution | `bmad.lens.release/_bmad/lens-work/skills/constitution.md` |
| sensing | `bmad.lens.release/_bmad/lens-work/skills/sensing.md` |
| checklist | `bmad.lens.release/_bmad/lens-work/skills/checklist.md` |

## Important

- This adapter references module content by path — it NEVER duplicates it
- Do not copy skills, workflows, or lifecycle definitions into `.github/`
- Module updates propagate automatically through path references
<!-- /LENS-WORK ADAPTER -->
```

---

# Copilot Adapter: bmad-agent-lens-work-lens.agent.md Template

This is the template for the `.github/agents/bmad-agent-lens-work-lens.agent.md` file.

---

```markdown
---
description: "LENS Workbench — guided lifecycle routing with git-orchestrated discipline"
---

# @lens Agent

Thin adapter that activates the LENS Workbench agent from the release module.

## Module Agent Reference

The full agent definition lives at:
`bmad.lens.release/_bmad/lens-work/agents/lens.agent.yaml`

## Available Commands

See `bmad.lens.release/_bmad/lens-work/module-help.csv` for the complete command list.

## Skills (path references)

- [git-state](bmad.lens.release/_bmad/lens-work/skills/git-state.md)
- [git-orchestration](bmad.lens.release/_bmad/lens-work/skills/git-orchestration.md)
- [constitution](bmad.lens.release/_bmad/lens-work/skills/constitution.md)
- [sensing](bmad.lens.release/_bmad/lens-work/skills/sensing.md)
- [checklist](bmad.lens.release/_bmad/lens-work/skills/checklist.md)

## Lifecycle Contract

All lifecycle semantics are defined in:
`bmad.lens.release/_bmad/lens-work/lifecycle.yaml`

This agent does NOT hardcode any lifecycle rules — everything is derived from the contract.
```
