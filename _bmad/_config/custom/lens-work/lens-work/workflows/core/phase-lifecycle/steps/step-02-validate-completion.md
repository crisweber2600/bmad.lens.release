---
name: 'step-02-validate-completion'
description: 'Verify required artifacts for the active phase before creating a PR'
nextStepFile: './step-03-create-phase-pr.md'
defaultDocsRoot: '{output_folder}/planning-artifacts'
---

# Step 2: Validate Phase Completion

**Goal:** Confirm that every required artifact for the active phase exists and contains content before a phase PR is created.

---

## EXECUTION SEQUENCE

### 1. Resolve Required Artifacts

```yaml
required_artifacts = lifecycle.phases[phase_name].artifacts || []
missing_artifacts = []
planning_docs_root = initiative.docs.path || "{defaultDocsRoot}"
bmad_docs_root = initiative.docs.bmad_docs || planning_docs_root

for artifact in required_artifacts:
  artifact_candidates = []

  if artifact == "product-brief":
    artifact_candidates = ["${planning_docs_root}/product-brief.md", "${planning_docs_root}/product-brief-*.md"]
  else if artifact == "research":
    artifact_candidates = ["${planning_docs_root}/research.md"]
  else if artifact == "brainstorm":
    artifact_candidates = ["${planning_docs_root}/brainstorm.md", "_bmad-output/brainstorming/*.md"]
  else if artifact == "prd":
    artifact_candidates = ["${planning_docs_root}/prd.md"]
  else if artifact == "ux-design":
    artifact_candidates = ["${planning_docs_root}/ux-design.md", "${planning_docs_root}/ux-design-specification.md"]
  else if artifact == "architecture":
    artifact_candidates = ["${planning_docs_root}/architecture.md", "${planning_docs_root}/*architecture*.md"]
  else if artifact == "epics":
    artifact_candidates = ["${planning_docs_root}/epics.md"]
  else if artifact == "stories":
    artifact_candidates = ["${planning_docs_root}/stories.md"]
  else if artifact == "implementation-readiness":
    artifact_candidates = ["${planning_docs_root}/readiness-checklist.md", "${planning_docs_root}/implementation-readiness.md"]
  else if artifact == "sprint-status":
    artifact_candidates = ["${planning_docs_root}/sprint-status.yaml", "${planning_docs_root}/sprint-backlog.md"]
  else if artifact == "story-files":
    artifact_candidates = ["${bmad_docs_root}/dev-story-*.md"]

  artifact_found = false
  for candidate in artifact_candidates:
    if file_exists(candidate) and trim(read(candidate)) != "":
      artifact_found = true
    else if glob_exists(candidate):
      matched_files = glob(candidate)
      for matched_file in matched_files:
        if trim(read(matched_file)) != "":
          artifact_found = true

  if artifact_found != true:
    missing_artifacts.append("${artifact}: ${artifact_candidates.join(' | ')}")

if missing_artifacts.length > 0:
  FAIL("❌ Phase incomplete. Missing required artifacts: ${missing_artifacts.join(', ')}")

output: |
  ✅ Phase artifacts verified
  ├── Required artifacts: ${required_artifacts.length}
  └── Missing artifacts: 0
```

### 2. Validation Rule

Use lifecycle-driven artifact requirements rather than hardcoded phase tables. If the lifecycle contract changes, this workflow must honor the contract instead of carrying a second copy of the rule set.

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`