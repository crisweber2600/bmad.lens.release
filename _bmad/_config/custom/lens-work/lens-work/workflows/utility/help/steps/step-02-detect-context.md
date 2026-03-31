---
name: 'step-02-detect-context'
description: 'Determine whether the user needs onboarding context or command recovery guidance'
nextStepFile: './step-03-load-registry.md'
---

# Step 2: Detect User Context

**Goal:** Decide whether this help request should include first-time-user guidance, command recovery guidance, or just the standard command reference.

---

## EXECUTION SEQUENCE

## CONTEXT BOUNDARIES

- Detect only onboarding and recovery context.
- Do not infer permissions, git state, or lifecycle progress from a help request.

### 1. Determine User Context

```yaml
first_time_user = not file_exists(profile_path)
recovery_mode = requested_command != null and requested_command != ""

if first_time_user:
  output: |
    👋 Welcome to LENS Workbench.

    LENS manages your planning lifecycle from idea to implementation using git-native workflows.
    Branches are state, PRs are gates, and lifecycle.yaml is the execution contract.

    Getting started:
    1. Run `/onboard` to authenticate and set up your profile
    2. Run `/new-domain {name}` to create your first initiative container
    3. Run `/next` anytime to see the recommended next action
else:
  output: "Returning user context detected. Rendering the command reference directly."

if recovery_mode:
  output: "Command recovery requested for: ${requested_command}"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`

## SUCCESS CRITERIA

- First-time users receive onboarding guidance.
- Returning users skip directly to the command reference.
- Recovery mode is explicitly surfaced when a command was supplied.