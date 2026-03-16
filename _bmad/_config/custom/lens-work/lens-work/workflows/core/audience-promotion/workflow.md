# Workflow: Audience Promotion

**Module:** lens-work
**Type:** Core workflow
**Trigger:** `/promote` command via `lens-work.promote.prompt.md`

---

## Purpose

Promote an initiative from the current audience tier to the next audience in the chain (small → medium → large → base) with comprehensive pre-promotion gate checks.

**Design Axiom A2:** Phase work and promotion are strictly separate operations. Promotion is NEVER automatic — always requires a reviewed and merged PR.

## Prerequisites

- User is on an initiative branch
- Current audience is determined from branch name
- Next audience exists in the audience chain

## Workflow Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Determine Current and Next Audience

1. Use `git-state` skill → `current-audience` to parse audience from branch name
2. Look up audience chain in `lifecycle.yaml`: small → medium → large → base
3. Determine next audience
4. If no next audience: report `✅ Initiative at final audience — no promotion available`

### Step 2: Pre-Promotion Gate Checks

Run ALL gate checks before creating the promotion PR:

#### 2a: Phase PR Verification

Use `git-state` skill to verify all required phase PRs for the current audience are merged:

| Current Audience | Required Merged Phase PRs |
|------------------|--------------------------|
| small | preplan, businessplan, techplan (per track) |
| medium | devproposal |
| large | sprintplan |

- Query provider adapter for PR status: `{root}-{audience}-{phase}` → `{root}-{audience}`
- If any required phase PR is NOT merged: **HARD GATE FAILURE**

#### 2b: Artifact Validation

Check required artifacts per the track's phase list:

1. Read committed artifacts on the current audience branch
2. Compare against lifecycle.yaml `phases[].artifacts` for each completed phase
3. If required artifacts are missing: **HARD GATE FAILURE**

#### 2c: Constitution Compliance Check

1. Invoke `constitution` skill → `resolve-constitution` for this initiative
2. Invoke `constitution` skill → `check-compliance` against resolved constitution
3. If hard gate failures exist: **HARD GATE FAILURE**
4. Informational failures: include as warnings in PR body

#### 2d: Cross-Initiative Sensing

1. Invoke `sensing` skill → `scan-initiatives` for this initiative's domain/service
2. Produce sensing report
3. Check if constitution upgrades sensing to hard gate for this domain
4. If hard gate + overlaps found: **HARD GATE FAILURE**
5. If informational (default): include results in PR body

### Step 3: Gate Check Result Processing

If ANY hard gate failed:

```
❌ Promotion blocked — gate check failures:

1. [HARD] Missing merged PR: {root}-{audience}-techplan → {root}-{audience}
2. [HARD] Required artifact missing: architecture.md for techplan phase

Resolve these issues and re-run /promote.
```

If all gates pass (with possible informational warnings): proceed to Step 4.

### Step 4: Create Next Audience Branch (Lazy)

1. Check if `{root}-{next-audience}` branch exists
2. If not: use `git-orchestration` skill → `create-branch` to create `{root}-{next-audience}` from `{root}` (the initiative root branch, NOT from the current audience branch)
3. If already exists: proceed (promotion was previously attempted or branch was pre-created)

### Step 5: Create Promotion PR

Use provider adapter to create PR:

- **From:** `{root}-{current-audience}`
- **To:** `{root}-{next-audience}`
- **Title:** `[PROMOTE] {initiative} {current}→{next} — Adversarial Review Gate`
- **Body:** Assembled from sections below

### Step 6: Assemble PR Body

Include the following sections in the promotion PR body:

```markdown
## Promotion Summary

**Initiative:** {initiative_root}
**Promotion:** {current_audience} → {next_audience}
**Track:** {track_type}

## Gate Check Results

{gate_check_summary — all passed}

## Compliance Status

{compliance_result from constitution check}

## Cross-Initiative Sensing

{sensing_report from sensing skill — see includes/sensing-report.md}

## Artifacts Summary

{list of committed artifacts by phase}

## Review Requirements

{gate requirements from lifecycle.yaml for the target audience}
- {entry_gate description}
- This PR requires review before merge
```

### Step 7: Report to User

```
✅ Promotion PR created: {pr_url}

[PROMOTE] {initiative} {current}→{next} — Adversarial Review Gate

The PR requires review and merge to complete promotion.
Sensing: {overlap_count} overlapping initiative(s) detected — see PR body.
```

### Step 8: Check for Further Promotions

After the promotion PR is created and the user is ready to proceed, inform them of potential chain promotions:

```
**Promotion Chain:**

Current:  small  → **PROMOTED TO →** medium
Next Available: medium → large (when devproposal is complete)

**To continue the promotion chain after this PR merges:**
1. Merge the current promotion PR
2. Run /devproposal to complete the medium audience phase
3. After devproposal completes, /promote will offer promotion to large

**Chain Status:**
- ✅ small → medium: In Progress (merge when gate checks pass)
- ⏳ medium → large: Requires devproposal + merge
- ⏳ large → base: Requires sprintplan + merge
```

This provides visibility into the full promotion lifecycle and helps users understand what comes next.

---

## Error Handling

| Error | Response |
|-------|----------|
| Not on initiative branch | `❌ Not on an initiative branch. Use /switch first.` |
| No next audience | `✅ Initiative is at final audience — no promotion needed.` |
| Hard gate failure | List all failures with actionable resolution steps |
| PR creation fails | `❌ Failed to create promotion PR. Check provider adapter config.` |
| Branch creation fails | `❌ Failed to create {next-audience} branch. Check git permissions.` |

## Key Constraints

- Promotion is NEVER automatic — always a reviewed PR
- Promotion PRs are merge PRs (not rebase or squash)
- Gate checks are cumulative — higher audiences have stricter gates
- Sensing report is always included, even when no overlaps found
- Constitution can upgrade any check from informational to hard gate
