---
name: 'step-03-update-guidance'
description: 'Confirm whether update guidance should continue and explain the update path'
nextStepFile: './step-04-compatibility-closeout.md'
---

# Step 3: Guided Update Flow

**Goal:** Keep updates guided and user-controlled, and explain exactly how module files should move from release into the control repo.

---

## EXECUTION SEQUENCE

### 1. Confirm Whether To Continue

```yaml
update_confirmed = false

if update_available:
  ask: "Proceed with update guidance for lens-work ${local_version} → ${latest_version}? [y/n]"
  capture: update_confirmation
  update_confirmed = lower(update_confirmation || "n") == "y"

if update_confirmed:
  output: |
    To update lens-work:
    1. Pull the latest `bmad.lens.release` repo content.
    2. Copy `bmad.lens.release/_bmad/lens-work/` into your control repo module location.
    3. Preserve initiative data under `_bmad-output/`.
else if update_available:
  output: "Update guidance skipped. Run module-management again whenever you want to update."
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`