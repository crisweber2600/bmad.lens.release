---
name: 'step-02-scan-initiatives'
description: 'Discover initiative roots from branch topology and handle the empty state'
nextStepFile: './step-03-derive-state.md'
---

# Step 2: Scan Initiative Branches

**Goal:** Discover the initiative roots that are currently active in the control repo, and stop early with a useful empty state when none exist.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Discover initiatives from branch topology only.
- Do not suppress legitimate initiative roots based on prefix heuristics.

### 1. Discover Initiative Roots

```yaml
initiative_inventory = invoke: git-state.active-initiatives
initiative_roots = map(initiative_inventory.initiatives, item -> item.root)

if initiative_roots == null:
  initiative_roots = []

initiative_roots = filter(initiative_roots, root -> root != null and root != "" and root != "main" and root != "develop")
initiative_roots = unique(initiative_roots)

if initiative_roots.length == 0:
  empty_state = true
  output: |
    ℹ️ No active initiatives.

    Get started:
    - `/new-domain {name}` - Create a domain-level initiative
    - `/new-service {domain}/{service}` - Create a service-level initiative
  exit: 0
else:
  empty_state = false
  output: |
    ✅ Initiative inventory complete
    ├── Initiative roots: ${initiative_roots.length}
    └── Roots: ${initiative_roots.join(", ")}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`

## SUCCESS CRITERIA

- An empty state is emitted when no initiatives exist.
- Otherwise, the deduplicated initiative root list is available for status derivation.