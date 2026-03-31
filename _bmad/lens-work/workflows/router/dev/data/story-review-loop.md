# Story Review Loop

Use this reference after implementation work for the active story has completed.

## Review, Party Mode, Story PR, And BMAD Control-Plane Updates

```yaml
story_check = load("${dev_story_path}")
story_status_check = story_check.status || story_check.Status || "unknown"
if story_status_check not in ["review", "in-progress"]:
  error: |
    ⛔ Code review blocked - story status is "${story_status_check}", not ready for review.
    Complete implementation and signal @lens done before proceeding.
  halt: true

invoke: git-orchestration.start-workflow
params:
  workflow_name: code-review

agent_persona: "_bmad/bmm/agents/qa.md"
read_and_follow: "_bmad/bmm/workflows/4-implementation/code-review/workflow.yaml"
params:
  target_repo: "${target_path}"
  branch: "${session.story_branch}"
  constitutional_context: ${constitutional_context}
  auto_fix_rerun: true
  auto_fix_severities: "CRITICAL,HIGH,MEDIUM"
  max_review_passes: 2
  on_max_passes: "needs_manual"

refreshed_context = invoke("constitution.resolve-context")
if refreshed_context.status != "parse_error":
  session.constitutional_context = refreshed_context

code_review_path = "_bmad-output/implementation-artifacts/code-review-${id}.md"
code_review_compliance = invoke("constitution.compliance-check")
params:
  artifact_path: ${code_review_path}
  artifact_type: "Code file"
  constitutional_context: ${session.constitutional_context}

if code_review_compliance.article_gate_results:
  review_gates = code_review_compliance.article_gate_results
  if review_gates.failed_gates > 0:
    output: |
      ═══ Post-Review Constitutional Re-Validation ═══
      ${for gate in review_gates.gates where gate.status == "fail"}
      ✗ Article ${gate.article_id}: ${gate.title} (${gate.source_layer})
        ${for item in gate.failed_items}
        -> ${item.violation}
        ${endfor}
      ${endfor}
    if enforcement_mode == "enforced":
      invoke: constitution.auto-resolve-gate-block
      params:
        failed_gates: ${review_gates}
        artifact_path: ${code_review_path}
        artifact_type: "Code file"
        initiative_id: ${initiative.id}
        source_branch: current_branch()
        gate_stage: "post-review-revalidation"
      halt: true
    else:
      warning: |
        ⚠️ ${review_gates.failed_gates} article gate warning(s) on code review.

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")

if code_review_compliance.fail_count > 0 and enforcement_mode == "enforced":
  invoke: constitution.auto-resolve-gate-block
  params:
    fail_count: ${code_review_compliance.fail_count}
    artifact_path: ${code_review_path}
    artifact_type: "Code file"
    initiative_id: ${initiative.id}
    source_branch: current_branch()
    gate_stage: "post-review-compliance-legacy"
  halt: true

read_and_follow: "_bmad/core/skills/bmad-party-mode/workflow.md"
params:
  input_file: ${code_review_path}
  artifacts_path: ${target_path}
  output_file: "_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md"
  constitutional_context: ${session.constitutional_context}
  complexity_tracking: ${complexity_tracking}

if party_mode.status not in ["pass", "complete"]:
  error: |
    Party mode teardown found unresolved issues for story ${story_id}.
    Address _bmad-output/implementation-artifacts/party-mode-review-${story_id}.md and fix issues.
  halt: true

reviewed_story = load(${dev_story_path})
reviewed_story_status = reviewed_story.status || reviewed_story.Status || reviewed_story.story_status || "unknown"
if reviewed_story_status != "done":
  output: |
    ⛔ PR blocked for ${story_id}
    ├── Post-review story status: ${reviewed_story_status}
    ├── Meaning: review follow-ups or unresolved fixes remain
    └── Action: resolve review items and re-review

  invoke: git-orchestration.finish-workflow
  halt: true

invoke: git-orchestration.create-pr
params:
  repo_path: ${target_path}
  source_branch: ${session.story_branch}
  target_branch: ${session.epic_branch}
  title: "feat(${session.epic_key}): ${story_id}"
  body: |
    Story ${story_id} completed and passed the dev -> review -> fix gate.

    Source branch: ${session.story_branch}
    Target branch: ${session.epic_branch}

    This PR was auto-created by /dev only after review fixes were resolved.
capture: story_pr_result

if story_pr_result.fallback:
  warning: |
    ⚠️ Auto-PR fallback triggered for story ${story_id}.
    Run this in target repo (${target_path}):
    gh pr create --base "${session.epic_branch}" --head "${session.story_branch}" --title "feat(${session.epic_key}): ${story_id}"
else:
  output: |
    ✅ Story PR auto-created
    ├── Branch: ${session.story_branch} -> ${session.epic_branch}
    └── URL: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result}

output: |
  📋 Story PR created - continuing to next story (no wait).
  ├── Story: ${story_id}
  ├── PR: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result || '(manual - see fallback above)'}
  └── ⚠️  Merge story PRs into epic before epic completion gate.

invoke: git-orchestration.finish-workflow

session.stories_completed.append(story_id)

invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/implementation-artifacts/"
  message: "[lens-work] /dev: Story ${story_id} complete - ${story_idx + 1}/${session.story_files.length}"
  branch: "${initiative.initiative_root}-dev"

output: |
  ✅ Story ${story_id} complete (${story_idx + 1}/${session.story_files.length})
  ├── Stories completed: ${session.stories_completed.length}
  └── Stories remaining: ${session.story_files.length - session.stories_completed.length}

endfor
```