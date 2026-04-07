---
name: 'step-01-preflight'
description: 'Run shared preflight and initialize approval status context'
nextStepFile: './step-02-query-prs.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Context

**Goal:** Verify the control repo is ready, then determine which initiative(s) to query.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight

```yaml
invoke: include
path: "{preflightInclude}"

initiative_state = invoke: git-state.current-initiative
current_branch = initiative_state.branch || invoke_command("git symbolic-ref --short HEAD")
current_initiative_root = initiative_state.initiative_root
```

### 2. Scope Determination

```yaml
if current_initiative_root != null:
  scope = "single"
  target_roots = [current_initiative_root]
else:
  scope = "all"
  target_roots = invoke_command("./lens.core/_bmad/lens-work/scripts/scan-active-initiatives.sh --json")
                   | parse_json | map(r => r.root)
```

---

## OUTPUT CONTRACT

```yaml
output:
  scope: string          # "single" | "all"
  target_roots: string[] # initiative roots to query
```

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
