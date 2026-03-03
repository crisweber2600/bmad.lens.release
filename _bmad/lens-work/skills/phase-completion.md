# Skill: phase-completion

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill — loaded JIT after last required sub-workflow completes
**Load trigger:** A sub-workflow marks itself complete and all other required sub-workflows for the current phase are already complete

---

## Purpose

Handles the transition from "all sub-workflows done" to "phase PR created and next phase started." This skill exists as a separate file so it can be loaded fresh (JIT) after context compaction, ensuring the agent always knows the correct completion procedure and auto-advance target regardless of how long the conversation has been.

## When to Load This Skill

Load this skill when ANY of these conditions are met:

1. **A sub-workflow just completed** and you need to check if it was the last required one
2. **`/next` determines** all required sub-workflows for the current phase are complete but phase completion hasn't run yet
3. **`/resume` detects** a phase with all sub-workflows complete but `phase_status` still shows `in_progress` (not `pr_pending` or `passed`)

---

## Part 1: Sub-Workflow Completion Check

### Procedure

1. Read `current_phase` from `_bmad-output/lens-work/state.yaml`
2. Read `sub_workflows.{current_phase}` from the initiative config file:
   - Feature/repo: `_bmad-output/lens-work/initiatives/{id}.yaml`
   - Domain: `_bmad-output/lens-work/initiatives/{id}/Domain.yaml`
   - Service: `_bmad-output/lens-work/initiatives/{domain}/{service}/Service.yaml`
3. Read the phase definition from `_bmad/lens-work/lifecycle.yaml` → `phases.{current_phase}.sub_workflows`
4. Cross-reference:

```
For each sub_workflow defined in lifecycle.yaml:
  required = lifecycle.phases[current_phase].sub_workflows[i].required
  status   = initiative_config.sub_workflows[current_phase][name]

  If required == true AND status NOT IN [complete]:
    → STOP. Report: "{name} is required but status is {status}. Phase completion blocked."
    → Exit skill. Do NOT proceed to Part 2.

  If required == false AND status IN [null]:
    → Mark as "skipped" (write to initiative config + state.yaml, dual-write)
    → Append event: sub_workflow_skipped
```

5. If ALL required sub-workflows have `status == complete`:
   → Log: "All required sub-workflows for {current_phase} are complete."
   → Proceed to **Part 2**

### Sub-workflow Status Values

| Value | Meaning |
|-------|---------|
| `null` | Not started |
| `skipped` | Optional, deliberately not run |
| `in_progress` | Started but not finished |
| `complete` | Finished successfully |

---

## Part 2: Phase Completion Procedure

### Pre-flight

1. Verify `phase_status.{current_phase}` is `in_progress` (not already `pr_pending` or `passed`)
   - If already `pr_pending`: skip to Part 3 (PR exists, check if merged)
   - If already `passed`: skip to Part 3 (phase done, just need auto-advance)
2. Verify current git branch matches the expected phase branch pattern
3. Verify working tree is clean (`git status --short` returns empty)
   - If dirty: stage and commit with message `"docs({phase}): complete {phase} phase artifacts"`

### Push & PR Creation

4. Push the phase branch:
   ```bash
   git push origin HEAD
   ```

5. Create a PR (promote phase branch → audience branch):

   **Determine the audience branch:**
   - Read phase audience from `lifecycle.yaml` → `phases.{current_phase}.audience`
   - Audience branch = `{initiative_root}-{audience}` (e.g., `printing-magic-printingmagic-baseline-small`)
   - Phase branch = `{initiative_root}-{audience}-{phase}` (e.g., `printing-magic-printingmagic-baseline-small-preplan`)

   **Create PR using promote-branch script:**

   *Bash:*
   ```bash
   bash _bmad/lens-work/scripts/promote-branch.sh \
     -s "{phase_branch}" \
     -t "{audience_branch}" \
     -T "Phase: {display_name} complete — {initiative_name}" \
     -b "## Phase: {display_name}\n\nAll sub-workflows complete:\n{sub_workflow_summary}\n\nArtifacts:\n{artifact_list}"
   ```

   *PowerShell:*
   ```powershell
   .\bmad.lens.release\_bmad\lens-work\scripts\promote-branch.ps1 `
     -SourceBranch "{phase_branch}" `
     -TargetBranch "{audience_branch}" `
     -Title "Phase: {display_name} complete — {initiative_name}" `
     -Body "## Phase: {display_name}\n\nAll sub-workflows complete..."
   ```

   If no PAT is available: inform user and provide manual PR creation instructions, but still proceed to state updates.

### State Updates (Dual-Write)

6. Update `phase_status.{current_phase}: pr_pending` in both:
   - `_bmad-output/lens-work/state.yaml`
   - Initiative config file
7. Update `workflow_status: idle` in `state.yaml`
8. Append event to `_bmad-output/lens-work/event-log.jsonl`:
   ```json
   {"ts":"ISO8601","event":"phase_completion_triggered","initiative":"{id}","user":"{name}","details":{"phase":"{current_phase}","sub_workflows":{completed_summary},"pr_created":true}}
   ```
9. Commit state updates:
   ```bash
   git add _bmad-output/lens-work/state.yaml _bmad-output/lens-work/initiatives/ _bmad-output/lens-work/event-log.jsonl
   git commit -m "lens(state): {phase} phase complete — PR created"
   git push
   ```

---

## Part 3: Auto-Advance

### Procedure

1. Read auto-advance configuration from `_bmad/lens-work/lifecycle.yaml`:
   ```yaml
   auto_advance_to = lifecycle.phases[current_phase].auto_advance_to
   auto_advance_promote = lifecycle.phases[current_phase].auto_advance_promote
   ```

2. **If `auto_advance_promote` is `true`:**
   - Execute audience promotion FIRST: `@lens promote`
   - This merges the audience branch up to the next audience tier
   - Wait for promotion to complete before proceeding

3. **Execute the auto-advance command:**
   - Run the `auto_advance_to` value as a lens command
   - Example: if `auto_advance_to: /businessplan`, execute `/businessplan`

### Auto-Advance Reference Table

| Phase | auto_advance_to | auto_advance_promote | Effect |
|-------|----------------|---------------------|--------|
| preplan | `/businessplan` | `false` | Same audience — directly start businessplan |
| businessplan | `/techplan` | `false` | Same audience — directly start techplan |
| techplan | `/devproposal` | `true` | Promote small→medium, then start devproposal |
| devproposal | `/sprintplan` | `true` | Promote medium→large, then start sprintplan |
| sprintplan | `/dev` | `true` | Promote large→base, then start dev |

### Edge Cases

- **PR creation failed (no PAT):** Still update state to `pr_pending`, inform user to create PR manually, but proceed with auto-advance since artifacts are pushed
- **Phase already `passed`:** Skip Parts 1-2, go directly to auto-advance
- **Phase already `pr_pending`:** The `/next` workflow detects this and checks if PR is merged using `git merge-base --is-ancestor`. If merged, it auto-updates status to `complete` and loads this skill. If not merged, `/next` pauses with merge instructions (this skill is not called). This ensures merged PRs advance automatically without requiring manual intervention.
- **No `auto_advance_to` defined:** Phase is terminal — just inform user "Phase complete. Use /next to continue."

---

## Context Resilience Notes

This skill is designed to be **loaded fresh on demand** — it does NOT depend on any prior conversation context. Everything it needs is read from:
- `state.yaml` → current_phase, active_initiative
- Initiative config file → sub_workflows, phase_status
- `lifecycle.yaml` → phase definitions, auto_advance_to, sub_workflows (required flags)

If an agent's context has been compacted and it can't remember what sub-workflows were completed, this skill will rediscover the complete state from persistent files and proceed correctly.
