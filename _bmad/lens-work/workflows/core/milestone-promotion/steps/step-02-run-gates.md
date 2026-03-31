---
name: 'step-02-run-gates'
description: 'Validate promotion gates for required phase completion, artifacts, constitution compliance, and sensing overlaps'
nextStepFile: './step-03-create-promotion.md'
artifactsRoot: '../../../_bmad-output/planning-artifacts'
---

# Step 2: Run Promotion Gates

**Goal:** Evaluate all required promotion gates and stop immediately if any hard gate remains unresolved.

---

## EXECUTION SEQUENCE

### 1. Evaluate Phase, Artifact, Constitution, And Sensing Gates

```yaml
track_name = initiative_config.track || "full"
enabled_phases = (lifecycle.tracks[track_name] != null and lifecycle.tracks[track_name].phases != null) ? lifecycle.tracks[track_name].phases : lifecycle.phase_order
milestone_phases = lifecycle.milestones[current_milestone].phases || []
required_phases = filter(milestone_phases, phase_name -> contains(enabled_phases, phase_name))

for each phase_name in required_phases:
  phase_state = invoke: git-state.phase-status
  params:
    phase: ${phase_name}

  if phase_state.status != "complete":
    append gate_failures with "[HARD] Required phase is not complete: ${phase_name}"

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
  phase: ${initiative_config.current_phase || required_phases[-1] || current_milestone}

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