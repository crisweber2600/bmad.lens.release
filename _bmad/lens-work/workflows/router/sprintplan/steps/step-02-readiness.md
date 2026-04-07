---
name: 'step-02-readiness'
description: 'Resolve constitutional context, run readiness validation, and enforce compliance gating'
nextStepFile: './step-03-sprint-planning.md'
readinessWorkflow: '{project-root}/lens.core/_bmad/bmm/workflows/3-solutioning/check-implementation-readiness/workflow.md'
---

# Step 2: Readiness And Compliance

## STEP GOAL:

Load constitutional context, validate implementation readiness, and block SprintPlan when compliance failures remain unresolved.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Treat readiness blockers and constitutional failures as hard stops.
- Preserve the resolved constitutional context for later SprintPlan steps.

### Role Reinforcement:
- You are the LENS control-plane router.
- Prevent sprint planning from starting until readiness and compliance gates are clean.

### Step-Specific Rules:
- Resolve constitutional context before running readiness validation.
- Use `{readinessWorkflow}` in validate mode only.
- Fail the step if any constitutional compliance failures remain.

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Persist `constitutional_context`, `readiness`, `compliance_checked`, and `compliance_warnings` into session state.
- Stop immediately on blockers or compliance failures.

## CONTEXT BOUNDARIES:
- Available context: `docs_path`, the planning artifacts, and `{readinessWorkflow}`.
- Focus: constitutional context, readiness blockers, and compliance gating.
- Limits: do not run sprint planning in this step.
- Dependencies: successful SprintPlan preflight and artifact gating.

---

## MANDATORY SEQUENCE

### 1. Constitutional Context Injection (Required)

Resolve constitutional context and store it in session state.

If constitutional parsing fails, stop and surface the parsing error details.

### 2. Re-run Readiness Checklist

Load and follow `{readinessWorkflow}` in validate mode, using the resolved constitutional context.

If readiness blockers remain, stop and require the user to resolve them before SprintPlan can continue.

### 2b. Epic/Story Completeness Summary

Before proceeding to compliance, scan the initiative's epic and story artifacts for completeness:

```yaml
epics_file = load_if_exists("${docs_path}/epics.md")
stories_file = load_if_exists("${docs_path}/stories.md")

epic_count = epics_file != null ? count_sections(epics_file, level=2) : 0
story_count = stories_file != null ? count_sections(stories_file, level=3) : 0
stories_with_ac = stories_file != null ? count_sections_with_content(stories_file, "acceptance criteria", level=3) : 0
stories_estimated = stories_file != null ? count_sections_with_content(stories_file, "estimate|points|size", level=3) : 0

output: |
  📋 Pre-SprintPlan Completeness

  | Metric | Count | Status |
  |--------|-------|--------|
  | Epics | ${epic_count} | ${epic_count > 0 ? "✅" : "⚠️ No epics found"} |
  | Stories | ${story_count} | ${story_count > 0 ? "✅" : "⚠️ No stories found"} |
  | With acceptance criteria | ${stories_with_ac}/${story_count} | ${stories_with_ac == story_count ? "✅" : "🟡 " + (story_count - stories_with_ac) + " missing AC"} |
  | With estimates | ${stories_estimated}/${story_count} | ${stories_estimated == story_count ? "✅" : "🟡 " + (story_count - stories_estimated) + " unestimated"} |

if story_count == 0:
  FAIL("❌ No stories found. Run /devproposal to create epics and stories before sprint planning.")
```

### 3. Constitutional Compliance Gate (Required)

Run constitutional compliance checks against each planning artifact that exists under `{docs_path}`.

Track how many artifacts were checked, collect warnings into `compliance_warnings`, and collect hard failures into `compliance_failures`.

If any compliance failures exist, stop the workflow and block SprintPlan until those violations are resolved.

### 4. Auto-Proceed

Display: "**Proceeding to sprint planning...**"

#### Menu Handling Logic:
- After readiness and compliance gates pass, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Stop only when readiness blockers or constitutional failures remain.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Constitutional context is resolved.
- Readiness validation runs in validate mode with zero blockers.
- Compliance checks complete with no hard failures.

### SYSTEM FAILURE:
- Constitutional context cannot be resolved.
- Readiness blockers remain.
- Any planning artifact fails constitutional compliance.

**Master Rule:** Skipping steps is FORBIDDEN.