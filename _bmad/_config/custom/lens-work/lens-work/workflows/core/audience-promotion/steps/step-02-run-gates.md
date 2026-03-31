---
name: 'step-02-run-gates'
description: 'Validate promotion gates for required merged phase PRs, artifacts, constitution compliance, and sensing overlaps'
nextStepFile: './step-03-create-promotion.md'
artifactsRoot: '../../../_bmad-output/planning-artifacts'
---

# Step 2: Run Promotion Gates

**Goal:** Evaluate all required promotion gates and stop immediately if any hard gate remains unresolved.

---

## EXECUTION SEQUENCE

### 1. Evaluate Phase, Artifact, Constitution, And Sensing Gates

```yaml
required_phases = lifecycle.audiences[current_audience].required_phases || []

for each phase_name in required_phases:
  phase_branch = "${initiative_root}-${current_audience}-${phase_name}"
  merge_check = invoke: git-orchestration.exec
  params:
    command: "git merge-base --is-ancestor origin/${phase_branch} origin/${source_branch}"

  if merge_check.exit_code != 0:
    append gate_failures with "[HARD] Missing merged PR for ${phase_branch}"

docs_path = initiative_config.docs.path || "{artifactsRoot}"

for each phase_name in required_phases:
  required_artifacts = lifecycle.phases[phase_name].artifacts || []
  for each artifact_name in required_artifacts:
    artifact_path = "${docs_path}/${artifact_name}"
    if not file_exists(artifact_path):
      append gate_failures with "[HARD] Required artifact missing: ${artifact_name} for ${phase_name}"

resolved_constitution = invoke: lens-work.resolve-constitution
compliance_result = invoke: constitution.check-compliance
params:
  constitution: ${resolved_constitution}
  artifacts_path: ${docs_path}
  phase: ${initiative_config.current_phase || current_audience}

if compliance_result.hard_failures exists and len(compliance_result.hard_failures) > 0:
  for each failure in compliance_result.hard_failures:
    append gate_failures with "[HARD] ${failure}"

sensing_result = invoke: lens-work.cross-initiative
params:
  enforce_gate: false

if sensing_result.gate_mode == "hard" and sensing_result.overlap_count > 0:
  append gate_failures with "[HARD] Cross-initiative sensing found ${sensing_result.overlap_count} overlap(s) under hard gate"

if len(gate_failures) > 0:
  output: |
    ❌ Promotion blocked — gate check failures:
    ${join(gate_failures, "\n")}
  exit: 1
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`