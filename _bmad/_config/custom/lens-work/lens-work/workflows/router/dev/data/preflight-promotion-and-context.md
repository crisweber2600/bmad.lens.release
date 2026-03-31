# Dev Pre-Flight Promotion And Context

Use this reference after the core `/dev` pre-flight branch setup in `steps/step-01-preflight.md`.

## Audience Promotion And Prior-Phase Checks

```yaml
# REQ-7/REQ-9: Validate previous phase (sprintplan) and audience promotion
prev_phase = "sprintplan"
prev_audience = "large"
prev_phase_branch = "${initiative.initiative_root}-${prev_audience}-sprintplan"
prev_audience_branch = "${initiative.initiative_root}-${prev_audience}"

if initiative.phase_status[prev_phase] exists:
  if initiative.phase_status[prev_phase] == "pr_pending":
    branch_exists_result = git-orchestration.exec("git ls-remote --heads origin ${prev_audience_branch}")
    prev_audience_branch_exists = (branch_exists_result.stdout != "")

    if prev_audience_branch_exists:
      result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_phase_branch} origin/${prev_audience_branch}")

      if result.exit_code == 0:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) PR merged - status updated to complete"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Previous phase (sprintplan) PR not yet merged
          ├── Status: pr_pending
          ├── PR: ${pr_url}
          └── You may continue, but phase artifacts may not be on the audience branch

        ask: "Continue anyway? [Y]es / [N]o"
        if no:
          exit: 0
    else:
      if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) complete - audience branch merged and deleted (large->base promotion passed)"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Audience branch ${prev_audience_branch} not found remotely
          ├── May have been deleted after PR merge
          ├── PR: ${pr_url}
          └── Proceeding - verify manually if needed

if initiative.question_mode == "batch":
  pass

if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Audience promotion validation pending
    ├── Required: large -> base promotion (constitution gate)
    └── ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0

sprintplan_branch = "${initiative.initiative_root}-large-sprintplan"
large_branch = "${initiative.initiative_root}-large"

sprintplan_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${sprintplan_branch}").stdout != ""
large_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${large_branch}").stdout != ""

if sprintplan_branch_exists and large_branch_exists:
  result = git-orchestration.exec("git merge-base --is-ancestor origin/${sprintplan_branch} origin/${large_branch}")

  if result.exit_code != 0:
    error: |
      ❌ Merge gate blocked
      ├── SprintPlan not merged into large audience branch
      ├── Expected: ${sprintplan_branch} is ancestor of ${large_branch}
      └── Action: Complete /sprintplan and merge PR first
else:
  if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
    output: "✅ Audience branch(es) deleted post-merge - large->base promotion already complete"
  else:
    output: |
      ⚠️  Audience branch(es) not found remotely
      ├── sprintplan: ${sprintplan_branch} (${sprintplan_branch_exists ? 'found' : 'gone'})
      ├── large: ${large_branch} (${large_branch_exists ? 'found' : 'gone'})
      └── Proceeding - verify manually if needed

if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Constitution gate still not passed for large -> base
    ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0
```

## Constitutional Context And Branch Assertion

```yaml
constitutional_context = invoke("constitution.resolve-context")

if constitutional_context.status == "parse_error":
  error: |
    Constitutional context parse error:
    ${constitutional_context.error_details.file}
    ${constitutional_context.error_details.error}

session.constitutional_context = constitutional_context

assert: current_branch == phase_branch
```