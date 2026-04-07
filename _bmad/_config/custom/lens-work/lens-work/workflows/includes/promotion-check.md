# Promotion Check

**Include with:** Reference this file at the end of phase router workflows to check if it's time to promote to the next audience.

**Purpose:** Determines if the current phase enables promotion and, if all phases for the current audience are complete, offers the promote workflow or script.

---

## Promotion Check Steps

### Step 0: Topology Guard (v3.4)

If `session.feature_yaml_context` is set and `session.feature_yaml_context.enabled == true`, skip all remaining steps. 2-branch topology does not use audience-based promotion — the plan→root PR model replaces it.

```yaml
if session.feature_yaml_context != null and session.feature_yaml_context.enabled == true:
  # No promotion check needed for 2-branch topology
  skip: all remaining steps
```

### Step 1: Read Current Phase Configuration

From `lifecycle.yaml`, read the current phase's configuration:
- `auto_advance_promote` (boolean) — indicates if promotion is available after this phase
- `branching_audience` (string) — the next audience tier to promote to

**Important:** All promotion operations in lens-work use PAT + GitHub REST API directly via scripts (`promote-branch.ps1/sh`, `create-pr.ps1/sh`). The `gh` CLI is never required or used.

**Phase Mapping:**
| Phase | auto_advance_promote | branching_audience |
|-------|----------------------|--------------------|
| preplan | false | — |
| businessplan | false | — |
| techplan | true | medium |
| devproposal | true | medium |
| sprintplan | true | large |

If `auto_advance_promote: false`, skip all remaining steps and do not offer promotion.

### Step 2: Extract Current State

From git branch names and PR metadata (via git-state skill):
1. **Current initiative root:** `${initiative.id}` (from branch name)
2. **Current audience:** Parse from highest audience branch: small → medium → large → base
3. **Current phase:** `${current_phase}` (derived from workflow context)

### Step 3: Check Audience Phase Completion

Query all phase statuses for the current audience:

**Algorithm:**
For each phase in the audience's phase list:
1. Check if phase branch exists: `{root}-{audience}-{phase}`
2. Check if phase PR is merged: query PR from `{root}-{audience}-{phase}` → `{root}-{audience}`
3. Mark phase as complete if PR is merged OR all artifacts exist on `{root}-{audience}` branch

**Current Audience Phase List (from lifecycle.yaml):**
- **small:** preplan, businessplan, techplan
- **medium:** devproposal
- **large:** sprintplan
- **base:** (no phases — execution environment)

### Step 4: Determine Promotion Readiness

If ALL phases for the current audience are complete:
```
✅ All phases for [${audience}] are complete and ready for promotion.

Next audience: ${branching_audience}

**[P]** Promote to /${branching_audience} (run promote workflow)
**[S]** Show status (@lens ST)
**[C]** Continue here (manage work on current audience)
```

If NOT all phases are complete:
```
ℹ️  Waiting for remaining phases in [${audience}] before promotion:

Completed:
  ✅ ${completed_phase_1}
  ✅ ${completed_phase_2}

Pending:
  ⏳ ${pending_phase_1}
  ⏳ ${pending_phase_2}

Continue with: /${next_phase}
```

### Step 5: Handle Promotion Command

If user selects **[P]** (Promote):

#### Option A: Use Promote Workflow (Recommended — Uses PAT + API)
Invoke the audience-promotion workflow using the shell (which internally uses promote-branch script with PAT + GitHub API):
```bash
# For PowerShell:
& .\lens.core\_bmad\lens-work\workflows\core\audience-promotion\workflow.md

# For Bash:
bash ./lens.core/_bmad/lens-work/workflows/core/audience-promotion/workflow.md
```

The promote workflow internally calls `promote-branch.ps1` or `promote-branch.sh`, which uses your PAT from `profile.yaml` to create PRs via GitHub REST API. No `gh` CLI required.

#### Option B: Use Promote Script Directly (Direct — Uses PAT + API)
If preferred, call the promote script directly with PAT support:
```bash
# For PowerShell:
& .\.\lens.core\_bmad\lens-work\scripts\promote-branch.ps1 `
  -SourceBranch "${initiative.id}-${audience}" `
  -CreatePR `
  -Cleanup

# For Bash:
./lens.core/_bmad/lens-work/scripts/promote-branch.sh \
  -s "${initiative.id}-${audience}" \
  --no-pr  # skip PR if you manually create via API
```

Both scripts use PAT from `profile.yaml` or `$GITHUB_TOKEN` / `$GH_TOKEN` environment variables. **Never relies on `gh` CLI.**

### Step 6: Output Result

After promotion completes:
```
🚀 Promotion initiated!

**From:** ${audience}
**To:** ${branching_audience}
**Steps:**
1. Review promotion PR
2. Merge when ready
3. Run /${next_phase_for_new_audience} to begin next phase

View status with: @lens /status
```

---

## Configuration Reference

**lifecycle.yaml phases with promotion:**

```yaml
techplan:
  auto_advance_promote: true
  branching_audience: medium   # Promote to medium audience after techplan

devproposal:
  auto_advance_promote: true
  branching_audience: medium   # Promote to medium audience after devproposal

sprintplan:
  auto_advance_promote: true
  branching_audience: large    # Promote to large audience after sprintplan
```

## Error Handling

| Condition | Action |
|-----------|--------|
| phase.auto_advance_promote = false | Skip promotion check; no option offered |
| Not all phases complete in audience | Show pending phases; do not offer promotion |
| Promotion script fails | Display error and retry instructions |
| User declines promotion | Continue on current audience; offer status/continue options |

## Usage Examples

### In a Phase Router Workflow

Add this at the end of router workflows (preplan, businessplan, techplan, devproposal, sprintplan):

```markdown
---

## Final Step: Promotion Readiness Check

Run the promotion-check include:

1. Execute `{project-root}/lens.core/_bmad/lens-work/workflows/includes/promotion-check.md`
2. If all phases for current audience are complete, present promotion options
3. If promotion selected, invoke the audience-promotion workflow
4. If declined, allow user to continue on current audience
```
