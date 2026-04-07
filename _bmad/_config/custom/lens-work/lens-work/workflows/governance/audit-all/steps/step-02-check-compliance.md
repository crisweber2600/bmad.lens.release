---
name: 'step-02-check-compliance'
description: 'Run compliance checks against each initiative'
nextStepFile: './step-03-render-report.md'
---

# Step 2: Compliance Checks

**Goal:** For each initiative, verify lifecycle compliance, artifact completeness, and structural consistency.

---

## EXECUTION SEQUENCE

### 1. Load Lifecycle Rules

```yaml
lifecycle = load: "{release_repo_root}/lens.core/_bmad/lens-work/lifecycle.yaml"
phase_order = lifecycle.phases | keys
```

### 2. Per-Initiative Checks

For each `entry` in `initiative_entries`:

```yaml
findings = []

# CHECK 1: initiative-state.yaml exists and is valid
state_file = "{entry.root}/initiative-state.yaml"
if not exists(state_file):
  findings.append({ check: "state-file", severity: "high", message: "Missing initiative-state.yaml" })
  continue

state = read_yaml(state_file)

# CHECK 2: Phase is valid
if state.phase not in phase_order:
  findings.append({ check: "valid-phase", severity: "high", message: "Unknown phase: ${state.phase}" })

# CHECK 3: Milestone is valid
milestone_names = lifecycle.milestones | keys
if state.milestone and state.milestone not in milestone_names:
  findings.append({ check: "valid-milestone", severity: "high", message: "Unknown milestone: ${state.milestone}" })

# CHECK 4: Artifact completeness for current phase
artifact_result = invoke_command("./lens.core/_bmad/lens-work/scripts/validate-phase-artifacts.sh '${entry.root}' --phase '${state.phase}' --json")
artifact_check = parse_json(artifact_result)
if artifact_check.missing and len(artifact_check.missing) > 0:
  findings.append({ check: "artifacts", severity: "medium", message: "Missing artifacts: ${artifact_check.missing | join(', ')}" })

# CHECK 5: Branch exists for current milestone
if state.milestone:
  branch_name = "{entry.root}-{state.milestone}"
  branch_exists = invoke_command("git branch --list '{branch_name}'") != ""
  if not branch_exists:
    findings.append({ check: "branch", severity: "medium", message: "Expected branch ${branch_name} not found" })

# CHECK 6: Stale pause (paused > 30 days)
if state.status == "paused" and state.paused_at:
  pause_age_days = days_since(state.paused_at)
  if pause_age_days > 30:
    findings.append({ check: "stale-pause", severity: "low", message: "Paused for ${pause_age_days} days" })

# CHECK 7: Constitution governance (if available)
constitution_file = "governance/constitution.yaml"
if exists(constitution_file):
  # Verify initiative scope is allowed by constitution
  constitution = read_yaml(constitution_file)
  if constitution.allowed_scopes and state.scope not in constitution.allowed_scopes:
    findings.append({ check: "constitution-scope", severity: "medium", message: "Scope '${state.scope}' not in allowed scopes" })

audit_findings[entry.root] = findings
```

---

## OUTPUT CONTRACT

```yaml
output:
  audit_findings: dict  # { initiative_root: [{ check, severity, message }] }
```

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
