# Phase Lifecycle Workflow

**Phase:** Core
**Purpose:** Manage phase completion, automatic PR creation, and branch cleanup.
**Trigger:** Automatically invoked at the end of each phase routing workflow.

## Overview

This core workflow handles the lifecycle of a phase branch:
1. **Phase Start** — Branch creation (handled by phase router)
2. **Phase Work** — Artifact production (handled by delegated agent)
3. **Phase End** — Automatic PR creation (this workflow)
4. **Branch Cleanup** — Phase branch deletion after PR merge

## Phase Completion Detection

A phase is complete when all required artifacts exist for that phase.

**Algorithm:**
1. Read `lifecycle.yaml` to get required artifacts for the current phase
2. Check file existence at `_bmad-output/lens-work/initiatives/{path}/phases/{phase}/`
3. All required artifacts must be present

| Phase | Required Artifacts |
|-------|--------------------|
| preplan | product-brief.md, research.md |
| businessplan | prd.md, ux-design.md |
| techplan | architecture.md |
| devproposal | epics.md |
| sprintplan | sprint-status.yaml |

## Auto-PR Creation

When phase work is complete, automatically create a PR:

### PR Source and Target

```
Source branch: {initiative-root}-{audience}-{phase}
Target branch: {initiative-root}-{audience}
```

### PR Title Format

```
[PHASE] {initiative-root} — {display_name} complete
```

Examples:
- `[PHASE] foo-bar-auth — PrePlan complete`
- `[PHASE] foo-bar-auth — TechPlan complete`

### PR Body Generation

The PR body is generated dynamically from committed artifact content (not hardcoded templates):

```markdown
## Phase Completion: {display_name}

**Initiative:** {initiative-root}
**Track:** {track}
**Audience:** {audience}
**Phase Agent:** {agent} ({agent_role})

### Artifacts Produced

- [x] `{artifact-1}.md` — {first line or heading from artifact}
- [x] `{artifact-2}.md` — {first line or heading from artifact}

### Artifact Summaries

#### {artifact-1}
{First paragraph or executive summary extracted from artifact content}

#### {artifact-2}
{First paragraph or executive summary extracted from artifact content}

### Phase Gate Requirements

| Requirement | Status |
|-------------|--------|
| All required artifacts present | ✅ |
| Artifact content non-empty | ✅ |
| Constitution compliance | {PASS/PENDING — integrated at Story 6.2} |

### Review Instructions

Review the artifacts for completeness, quality, and alignment with initiative goals.
Merge this PR to mark the {display_name} phase as complete.
```

### PR Creation

Use provider-adapter `create-pr`:

```yaml
title: "[PHASE] {initiative-root} — {display_name} complete"
body: "{generated body}"
source_branch: "{initiative-root}-{audience}-{phase}"
target_branch: "{initiative-root}-{audience}"
```

### Response

```
✅ Phase PR created

## PR Details
- **Title:** [PHASE] {initiative-root} — {display_name} complete
- **URL:** {pr_url}
- **Artifacts included:** {count} files
- **Review required:** Yes — merge to complete this phase

## Next Step
Merge the PR, then run `/{next_phase}` to continue.
```

## Phase Branch Cleanup

After a phase PR is merged, the phase branch should be cleaned up.

### Detection

Branch cleanup is triggered lazily when `/next` or `/status` detects a merged phase PR with an existing phase branch.

### Algorithm

1. Check if PR from `{root}-{audience}-{phase}` → `{root}-{audience}` is merged (via provider-adapter `query-pr`)
2. If merged AND phase branch still exists:
   ```bash
   git branch -d {root}-{audience}-{phase}        # Delete local
   git push origin --delete {root}-{audience}-{phase}  # Delete remote
   ```
3. Report cleanup:
   ```
   🧹 Cleaned up merged phase branch `{root}-{audience}-{phase}`
   ```

### Safety

- **ALWAYS** verify PR is merged before deletion (via provider-adapter)
- Phase completion state is preserved in PR metadata — branch deletion doesn't lose state
- git-state derives phase completion from PR metadata, NOT branch existence

## Error Handling

| Error | Response |
|-------|----------|
| Missing required artifacts | `❌ Phase incomplete. Missing: {artifact-list}. Complete these before PR creation.` |
| PR creation fails | `❌ PR creation failed: {error}. Check provider authentication with /onboard.` |
| Branch cleanup on unmerged PR | Abort — never delete an unmerged phase branch |
