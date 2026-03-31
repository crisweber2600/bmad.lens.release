---
name: 'step-02-select-mode'
description: 'Capture the devproposal execution mode and stress-gate profile'
nextStepFile: './step-03-run-workflows.md'
---

# Step 2: Select The DevProposal Run Profile

**Goal:** Decide whether devproposal runs in batch or interactive mode and whether epic stress gates run in the current pass.

---

## EXECUTION SEQUENCE

### 1. Capture Mode And Stress-Gate Profile

```yaml
ask: "Execution mode? [interactive/batch]"
capture: execution_mode

ask: "Run adversarial and party-mode epic stress gates in this pass? [yes/no]"
capture: stress_gate_choice

run_epic_stress_gate = lower(stress_gate_choice || "yes") != "no"

if execution_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "devproposal"
    display_name: "DevProposal"
    template_path: "templates/devproposal-questions.template.md"
    output_filename: "devproposal-questions.md"
    scope: "phase"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`