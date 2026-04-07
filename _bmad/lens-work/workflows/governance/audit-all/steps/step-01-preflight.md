---
name: 'step-01-preflight'
description: 'Run shared preflight and scan all active initiatives'
nextStepFile: './step-02-check-compliance.md'
preflightInclude: '../../../includes/preflight.md'
---

# Step 1: Preflight And Initiative Scan

**Goal:** Run preflight, then enumerate all active initiatives.

---

## EXECUTION SEQUENCE

### 1. Shared Preflight

```yaml
invoke: include
path: "{preflightInclude}"
```

### 2. Scan All Initiatives

```yaml
scan_result = invoke_command("./lens.core/_bmad/lens-work/scripts/scan-active-initiatives.sh --json")
initiative_entries = parse_json(scan_result)

if len(initiative_entries) == 0:
  output: "ℹ️ No active initiatives found. Nothing to audit."
  STOP

output: "📋 Found ${len(initiative_entries)} active initiative(s). Running compliance checks..."
```

---

## OUTPUT CONTRACT

```yaml
output:
  initiative_entries: list  # [{root, phase, milestone, status, ...}]
```

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
