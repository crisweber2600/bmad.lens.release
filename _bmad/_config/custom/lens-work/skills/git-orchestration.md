# Skill: git-orchestration

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Manages all git branch operations for the lens-work lifecycle. Handles branch creation, targeted commits, pushes, and topology validation. Formalizes the git-orchestration skill's API contract.

## Responsibilities

1. **Repository cloning** — Clone repos and auto-checkout to last-committed branch
2. **Branch creation** — Create initiative root, audience, and phase branches
3. **Branch validation** — Verify topology matches expected patterns
4. **Targeted commits** — Commit only relevant files per workflow
5. **Push management** — Push branches at workflow boundaries
6. **PR preparation** — Set up pull request metadata
7. **Target project branching** — Epic/story branch creation, task auto-commit, story auto-PR

## Branch Patterns (v2 — Lifecycle Contract)

```yaml
domain: "{domain_prefix}"
service: "{domain_prefix}-{service_prefix}"
root: "{initiative_root}"
audience: "{initiative_root}-{audience}"
phase: "{initiative_root}-{audience}-{phase_name}"
workflow: "{initiative_root}-{audience}-{phase_name}-{workflow}"

# Branch patterns use named phases only (v2.0.0)
```

> Named phases: preplan, businessplan, techplan, devproposal, sprintplan
> Audiences: small (IC creation), medium (lead review), large (stakeholder), base (initiative root)

## Trigger Conditions

- Initiative creation (`/new-*`) — create root + audience branches (track-aware)
- Phase start — create named phase branch from audience
- Workflow start — create workflow branch from phase
- Workflow end — commit, push
- Phase end — PR into audience branch, delete phase branch
- Audience promotion — PR from one audience to next (with gate validation)

## Git Discipline Rules

1. Clean working directory before any branch operation
2. Targeted commits (only files relevant to current workflow)
3. **Auto-push: EVERY commit MUST be immediately followed by `git push`** (bmadconfig.yaml: git_discipline.auto_push)
4. Workflow end: verify branch is fully pushed and clean. With `git_discipline.auto_push` enabled, every commit is already pushed; if auto-push is disabled, perform a single push of any accumulated commits here (no ad-hoc mid-workflow pushes).
5. Never force-push without explicit user confirmation
6. Use `{default_git_remote}` from config for all remote operations

## Target Project Branch Management

Target project repos follow the GitFlow branching model defined in `lifecycle.yaml → target_projects`.

### Branch Naming Contract

- **Epic branch:** `feature/{epic-key}` (e.g., `feature/epic-1`)
- **Story branch:** `feature/{epic-key}-{story-key}` (e.g., `feature/epic-1-1-1-user-authentication`)

### Automation Rules

| Trigger | Action |
|---------|--------|
| Dev story starts | Ensure epic branch exists (from develop/main), create story branch from epic |
| Task marked complete | Auto-commit + push to story branch: `feat({story-key}): {task-desc}` |
| All story tasks done | Auto-create PR: story branch → epic branch |
| All epic stories done | Auto-create PR: epic branch → develop |

## Error Handling

| Error | Recovery |
|-------|----------|
| Branch exists | Check if it's the expected branch, use it or error |
| Dirty working directory | Prompt user to commit or stash |
| Push rejected | Suggest pull + merge or /sync |
| Branch topology drift | Report mismatch, suggest /fix |

## State Fields Touched

- `state.current_phase` (v2: named phase — preplan|businessplan|techplan|devproposal|sprintplan)
- `state.phase_status` (v2: named phase keys)
- `state.audience_status` (v2: promotion tracking — small_to_medium|medium_to_large|large_to_base)
- `initiative.initiative_root` (v2: replaces featureBranchRoot)
- `initiative.active_phases` (v2: derived from track)
- `initiative.audiences` (v2: derived from track)

---

_Skill spec backported from lens module on 2026-02-17_
