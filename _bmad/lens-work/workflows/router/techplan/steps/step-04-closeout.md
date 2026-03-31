---
name: 'step-04-closeout'
description: 'Commit techplan artifacts, create milestone branch and PR, update state, and report the next command'
createPrScript: '../../../../scripts/create-pr.ps1'
---

# Step 4: Close Out The TechPlan Phase

**Goal:** Commit the generated techplan artifacts with a phase-complete marker, create the `{initiative_root}-techplan` milestone branch, open a PR, and surface the next lifecycle command.

---

## EXECUTION SEQUENCE

### 1. Validate Artifacts, Commit, Create Milestone Branch, And Open PR

```yaml
has_architecture = file_exists("${docs_path}/architecture.md")
has_decisions = file_exists("${docs_path}/tech-decisions.md")

if not has_architecture or not has_decisions:
  FAIL("❌ TechPlan phase incomplete. Required artifacts are missing from ${docs_path}.")

# Commit artifacts with phase-complete marker and inline artifact list
artifact_list = list_files(docs_path)

# Update initiative-state.yaml: phase complete, milestone, record artifacts
invoke: git-orchestration.update-phase-complete
params:
  phase: techplan
  artifacts: ${artifact_list}

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${docs_path}
    - ${initiative_state.state_path}
  phase: "PHASE:TECHPLAN:COMPLETE"
  initiative: ${initiative.initiative_root}
  description: "techplan artifacts complete"
  commit_body: |
    Artifacts:
    ${artifact_list.join('\n    - ')}

invoke: git-orchestration.push

# v3: Create the techplan milestone branch from current HEAD
milestone_branch = "${initiative.initiative_root}-techplan"

invoke: git-orchestration.create-milestone-branch
params:
  milestone: "techplan"
  initiative_root: ${initiative.initiative_root}
  source_branch: ${initiative.initiative_root}
  new_branch: ${milestone_branch}

invoke: git-orchestration.update-milestone-promote
params:
  milestone: techplan

# Create PR from milestone branch for review
pr_result = invoke: script
script: "{createPrScript}"
params:
  SourceBranch: ${milestone_branch}
  TargetBranch: main
  Title: "[MILESTONE] ${initiative.initiative_root} - TechPlan milestone"
  Body: "TechPlan milestone for ${initiative.initiative_root}. Review architecture, technical decisions, and constitution compliance before merging."

output: |
  ✅ /techplan complete
  ├── Branch: ${milestone_branch} (milestone branch created)
  ├── PR: ${pr_result.Url || pr_result.url || "manual creation required"}
  └── Next: Run `/devproposal` on the techplan milestone branch after PR review.
```