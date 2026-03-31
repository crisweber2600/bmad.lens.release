---
name: 'step-04-closeout'
description: 'Commit devproposal artifacts, create the devproposal milestone branch, open PR, update state, and report the next command'
promotionCheckInclude: '../../../includes/promotion-check.md'
createPrScript: '../../../../scripts/create-pr.ps1'
---

# Step 4: Close Out The DevProposal Phase

**Goal:** Commit the generated devproposal artifacts, create the `{initiative_root}-devproposal` milestone branch, open a PR, update initiative state, and surface the next lifecycle command.

---

## EXECUTION SEQUENCE

### 1. Validate Artifacts, Commit, Create Milestone Branch, And Open PR

```yaml
has_epics = file_exists("${docs_path}/epics.md")
has_stories = file_exists("${docs_path}/stories.md")
has_readiness = file_exists("${docs_path}/readiness-checklist.md")

if not has_epics or not has_stories:
  FAIL("❌ DevProposal phase incomplete. Required artifacts are missing from ${docs_path}.")

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${docs_path}
  phase: DEVPROPOSAL
  initiative: ${initiative.initiative_root}
  description: "devproposal artifacts complete"

# --- Phase complete marker ---
invoke: git-orchestration.update-phase-complete
params:
  initiative_id: ${initiative.id || initiative_root}
  phase: "devproposal"
  branch: ${current_branch}
  commit_message: |
    [PHASE:DEVPROPOSAL:COMPLETE] DevProposal artifacts finalized
    Artifacts: epics.md, stories.md, readiness-checklist.md
  artifacts:
    - epics.md
    - stories.md
    - readiness-checklist.md

# --- Create milestone branch ---
devproposal_branch = "${initiative_root}-devproposal"

invoke: git-orchestration.create-milestone-branch
params:
  milestone: "devproposal"
  initiative_root: ${initiative_root}
  source_branch: ${current_branch}
  new_branch: ${devproposal_branch}

invoke: git-orchestration.push
params:
  branch: ${devproposal_branch}

# --- Open PR ---
compliance_status = invoke: lens-work.compliance-check
params:
  phase: "devproposal"
  artifacts_path: ${docs_path}

sensing_report = invoke: lens-work.sensing
params:
  initiative_root: ${initiative_root}

pr_result = invoke: script
script: "{createPrScript}"
params:
  SourceBranch: ${devproposal_branch}
  TargetBranch: main
  Title: "[MILESTONE] ${initiative.id || initiative.initiative_root} - DevProposal complete"
  Body: |
    DevProposal milestone for ${initiative.initiative_root}.
    Constitution compliance: ${compliance_status}
    Sensing report: ${sensing_report}
    Review epics, stories, and readiness artifacts before merging.

# --- Update initiative state ---
invoke: git-orchestration.update-milestone-promote
params:
  initiative_id: ${initiative.id || initiative_root}
  milestone: "devproposal"
  phase: "devproposal"
  phase_status: "complete"

invoke: include
path: "{promotionCheckInclude}"
params:
  current_phase: "devproposal"
  initiative_root: ${initiative.initiative_root}
  lifecycle_contract: ${lifecycle}

output: |
  ✅ /devproposal complete
  ├── Milestone branch: ${devproposal_branch}
  ├── PR: ${pr_result.Url || pr_result.url || "manual creation required"}
  └── Next: Run `/sprintplan` after the milestone PR is reviewed.
```