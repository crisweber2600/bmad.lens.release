---
name: 'step-01-validate'
description: 'Validate initiative is active and closeable, parse close variant, collect close reason'
nextStepFile: './step-02-tombstone.md'
lifecycleContract: '../../../../lifecycle.yaml'
---

# Step 1: Validate and Collect Close Parameters

**Goal:** Confirm the initiative is active and eligible for closure, parse the close variant, and collect the close reason from the user.

---

## EXECUTION SEQUENCE

### 1. Parse Close Command Variant

```yaml
# Parse the /close command arguments
if args contains "--completed":
  close_state = "completed"
  superseded_by = null
elif args contains "--abandoned":
  close_state = "abandoned"
  superseded_by = null
elif args contains "--superseded-by":
  close_state = "superseded"
  superseded_by = extract_value_after("--superseded-by")
  if not superseded_by:
    error: "❌ --superseded-by requires an initiative slug. Usage: /close --superseded-by {initiative}"
    STOP
else:
  error: |
    ❌ Missing close variant. Usage:
      /close --completed
      /close --abandoned
      /close --superseded-by {initiative}
  STOP
```

### 2. Validate Initiative State

```yaml
# Load and validate initiative-state.yaml
state_yaml = load("initiative-state.yaml")
if not state_yaml:
  error: "❌ No initiative-state.yaml found. Cannot close an uninitialized initiative."
  STOP

if state_yaml.lifecycle_status != "active":
  error: "❌ Initiative already closed (status: ${state_yaml.lifecycle_status}). Cannot close again."
  STOP

# Validate close_state against lifecycle.yaml
valid_states = load("{lifecycleContract}").close_states
if close_state not in valid_states:
  error: "❌ Invalid close state '${close_state}'. Valid: ${valid_states}"
  STOP

# Load initiative config for domain/service
initiative_config = load_initiative_config()
initiative = state_yaml.initiative || initiative_config.initiative
domain = initiative_config.domain
service = initiative_config.service
```

### 3. Collect Close Reason

```yaml
# Prompt user for close reason
close_reason = prompt: |
  Closing initiative **${initiative}** as **${close_state}**.
  
  Please provide a brief reason for this closure:

if not close_reason or close_reason.strip() == "":
  close_reason = "No reason provided"
```

### 4. Confirm Close Action

```yaml
output: |
  ⚠️ Closing Initiative
  ├── Initiative: ${initiative}
  ├── Domain: ${domain}
  ├── Service: ${service}
  ├── Close State: ${close_state}
  ├── Superseded By: ${superseded_by || 'N/A'}
  ├── Final Milestone: ${state_yaml.milestone || 'none'}
  └── Reason: ${close_reason}

  This action is permanent. Proceed? (y/n)

confirmation = prompt_yn()
if not confirmation:
  output: "Close cancelled."
  STOP
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
