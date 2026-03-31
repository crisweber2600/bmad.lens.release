---
validationStatus: COMPLETE
validationDate: 2026-03-23
validationReport: './validation-report-2026-03-23.md'
---

# Workflow Plan: dev

## Goal

Implement every story in a selected epic inside the TargetProject repo, run constitutional and review gates per story, then close the epic through the initiative branch.

## Step Structure

1. `steps/step-01-preflight.md`
   - Resolve initiative context
   - Resolve and validate the target repo
   - Ensure large-to-base promotion is complete
   - Inject constitutional context and branch assertions
2. `steps/step-02-story-discovery.md`
   - Handle batch-mode question runs
   - Discover ordered story files for the epic
   - Confirm execution scope with the user
3. `steps/step-03-story-loop.md`
   - Loop through each story
   - Enforce story-level gates
   - Route branch setup and write guards
   - Surface implementation guidance and run the review/PR loop
4. `steps/step-04-epic-completion.md`
   - Run epic-level adversarial and party-mode checks
   - Create epic PR into the initiative branch
   - Wait at the hard merge gate
5. `steps/step-05-closeout.md`
   - Offer retrospective
   - Update state and event log
   - Complete the initiative when all phases are done

## Supporting Data Files

- `data/preflight-promotion-and-context.md`
- `data/story-target-repo-routing.md`
- `data/story-implementation-guidance.md`
- `data/story-review-loop.md`

## Key State

- `initiative`
- `docs_path`
- `bmad_docs`
- `phase_branch`
- `constitutional_context`
- `story_files`
- `stories_completed`
- `target_repo`
- `target_path`
- `initiative_branch`
- `epic_branch`
- `story_branch`
- `resolved_integration_branch`
- `epic_number`
- `special_instructions`
- `story_id`
- `code_review_path`
- `epic_pr_result`

## Output Artifacts

- `_bmad-output/implementation-artifacts/code-review-${id}.md`
- `_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md`
- `_bmad-output/implementation-artifacts/epic-*-party-mode-review.md`
- `_bmad-output/implementation-artifacts/retro-${id}.md`
- `_bmad-output/lens-work/initiatives/${id}.yaml`
- `_bmad-output/lens-work/event-log.jsonl`