---
name: 'step-03-handle-dirty-state'
description: 'Protect uncommitted work before switching branches'
nextStepFile: './step-04-checkout-target.md'
---

# Step 3: Handle Dirty Working Tree State

**Goal:** Ensure the branch switch never discards local work by forcing an explicit commit, stash, or abort decision.

---

## EXECUTION SEQUENCE

### 1. Check For Uncommitted Changes

```yaml
dirty_state = invoke: git-orchestration.check-dirty

if dirty_state.status == "dirty":
  output: |
    ⚠️ Uncommitted changes detected.
    ├── Files changed: ${dirty_state.files_changed || 0}
    └── Files: ${(dirty_state.files || []).join(', ')}

    Choose: [c] commit, [s] stash, or [a] abort.
  ask: "How should /switch handle the current changes?"
  capture: dirty_action

  if dirty_action == "c":
    ask: "Provide the commit message for the current changes."
    capture: commit_message
    invoke_command("git add -A && git commit -m \"${commit_message}\"")
  else if dirty_action == "s":
    invoke_command("git stash push -m \"lens-switch: ${target_root}\"")
  else:
    FAIL("❌ Switch aborted to preserve the current working tree.")
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`