# Workflow Plan: next

## Goal

Determine the single next lifecycle action from git-derived status and execute it automatically when no approval or gate blocks progress.

## Step Structure

1. `steps/step-01-preflight.md`
   - Run shared preflight
   - Capture the internal `/status` snapshot
2. `steps/step-02-derive-action.md`
   - Apply lifecycle rules in priority order
   - Decide whether to execute, gate, or stop cleanly
3. `steps/step-03-execute-or-report.md`
   - Render the context header
   - Execute the next workflow or report the hard gate

## Key State

- `status_snapshot`
- `current_row`
- `next_command`
- `gate_message`
- `hard_gate`

## Output Artifacts

- None. `/next` routes into another workflow or emits a gate/terminal message.