# /next — Determine and Execute Next Action Workflow

**Phase:** Utility
**Purpose:** Automatically determine the single next action based on git-derived lifecycle state, then **execute it** — eliminating the two-step "check status → run command" pattern.

## Pre-conditions

- User is on an initiative branch (or control repo with initiatives)

## Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.
2. If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Run /status Internally

Execute the status workflow internally (no output to user) to derive:
- Current initiative and branch
- Current phase and audience
- PR status (open, merged, closed)
- Completed phases
- Track phases remaining

### Step 2: Apply Lifecycle Rules and Execute

Read `lifecycle.yaml` to determine phase ordering for the current track. Apply rules in priority order. **When a rule matches an actionable state, execute the action immediately** — do not merely recommend it.

**Rule 0a — On a domain branch (no audience, no phase):**
If the current branch is a domain root (scope: domain, no audience/phase suffix):
```
📋 Domain `{domain}` is an organizational container — services hold features, features hold phases.
▶️ Executing `/new-service`...
```
Then invoke: `/new-service`

**Rule 0b — On a service branch (no audience, no phase):**
If the current branch is a service root (scope: service, no audience/phase suffix):
```
📋 Service `{service}` is an organizational container — features hold lifecycle phases.
▶️ Executing `/new-feature`...
```
Then invoke: `/new-feature`

**Rule 1 — Phase in progress, not complete:**
If current phase branch exists and no PR created yet:
```
🔄 Phase `{current-phase}` is in progress.
▶️ Continuing `/{current-phase}`...
```
Then invoke: `/{current-phase}`

**Rule 2 — Phase PR open, awaiting review:**
If PR from `{root}-{audience}-{phase}` → `{root}-{audience}` is open:
```
⏳ Phase `{phase}` PR is open and awaiting review.
   PR: {pr-url}
   Merge the PR, then run `/next` again.
```
**(No execution — this is a hard gate. User must merge the PR.)**

**Rule 3 — Phase complete, next phase available:**
If the current phase PR is merged and the next phase in the track exists:
```
✅ Phase `{phase}` complete.
▶️ Starting `/{next-phase}`...
```
Then invoke: `/{next-phase}`

**Rule 4 — All phases for current audience complete, promotion available:**
If all phases for the current audience are done (PRs merged):
```
✅ All `{audience}` phases complete.
▶️ Executing `/promote`...
```
Then invoke: `/promote`

**Rule 5 — Promotion PR open:**
If a promotion PR is open:
```
⏳ Promotion PR `{audience}` → `{next-audience}` is open and awaiting review.
   PR: {pr-url}
   Merge the PR, then run `/next` again.
```
**(No execution — hard gate.)**

**Rule 5b — Promotion merged, entry gate pending:**
If a promotion PR is merged AND the target audience has an `entry_gate` in lifecycle.yaml (e.g., `adversarial-review`, `stakeholder-approval`, `constitution-gate`) AND the entry gate has NOT been completed:

1. Read the target audience's `entry_gate` and `entry_gate_mode` from lifecycle.yaml
2. Check if the entry gate was executed by looking for the gate artifact:
   - For `adversarial-review`: check if `{docs_path}/adversarial-review-report.md` exists on the target audience branch
   - For other gates: check for the corresponding gate artifact
3. If the gate artifact does NOT exist → the entry gate was skipped. Execute it now:

```
✅ Promotion `{audience}` → `{next-audience}` merged.
⚠️ Entry gate `{entry_gate}` has not been completed.
▶️ Executing entry gate: {entry_gate} ({entry_gate_mode} mode)...
```
Then invoke the entry gate workflow:
- `adversarial-review` → Run adversarial review in party mode on all planning artifacts committed to the target audience branch. The review covers: product-brief, prd, ux-design, architecture (per lifecycle.yaml `adversarial_review.reviews`). Save the review report to `{docs_path}/adversarial-review-report.md`, commit to the target audience branch, and proceed.
- `stakeholder-approval` → Invoke stakeholder approval workflow.
- `constitution-gate` → Invoke constitution gate workflow.

4. If the gate artifact DOES exist:
   a. Parse the `verdict` field from the report frontmatter
   b. If verdict is `PASS` or `PASS_WITH_NOTES` → gate completed, proceed to the first phase of the new audience
   c. If verdict is `PROCEED_WITH_BLOCKERS` or `REJECT`:

   ```
   ⛔ Entry gate `{entry_gate}` completed but found blockers.
      Report: {gate_artifact_path}
      Verdict: {verdict}
      Resolve all blockers in the planning artifacts, then delete the report
      and run `/next` again to re-run the entry gate.
   ```
   **(No execution — this is a hard gate. User must resolve blockers before proceeding.)**

**(This is an execution rule — the entry gate runs automatically before advancing. A non-passing verdict is a hard gate.)**

**Rule 6 — Track fully complete:**
If the initiative has reached the final audience and all gates are passed:
```
✅ All caught up — no pending actions.
   Initiative `{initiative-root}` has completed the `{track}` lifecycle.
```
**(No execution — nothing left to do.)**

**Rule 7 — No initiative context:**
If the user is not on an initiative branch:
```
ℹ️ Not currently on an initiative branch.
   Run `/status` to see all initiatives, or `/switch` to select one.
```
**(No execution — cannot determine target.)**

### Step 3: Display Context Header Before Execution

Before invoking any phase or promotion workflow, always display the context header first:

```
📂 Initiative: {initiative-root}
🏷️ Track: {track}
👥 Audience: {audience}
📋 Phase: {current-phase} → {action}
```

Then immediately execute the determined workflow. The invoked workflow's own pre-flight will handle branch checkout, pull latest, and workspace setup — `/next` does NOT need to duplicate those steps.

### Step 4: Execution Handoff

When invoking a phase workflow (e.g., `/{next-phase}`):
- The phase workflow's pre-flight handles: branch creation/checkout, pull latest, state verification
- `/next` does NOT provide manual `git checkout` or `git pull` instructions — those are the phase workflow's responsibility
- `/next` simply invokes the workflow and yields control

When the matched rule is a hard gate (Rules 2, 5) or terminal state (Rules 6, 7):
- Display the status message only — no workflow invocation
- For hard gates: tell user what to do (merge PR) and to run `/next` again after

## Design Principles

- `/next` is the "killer UX feature" — it removes decision fatigue AND execution overhead
- ONE directive, then **execute** — not a menu, not a recommendation
- Eliminates the two-step "check status → run command" pattern
- "All caught up" is a positive, calm message — not an error
- Hard gates (open PRs) are the only case where `/next` does NOT execute — user action required
- Lifecycle rules come from lifecycle.yaml — never hardcode phase ordering
- Phase ordering: follows the track's `phases:` array and audience progression
- Phase workflows own their own pre-flight (branch checkout, pull) — `/next` does NOT duplicate this

## NFR Compliance

- **NFR1:** All state derived from git — no secondary state stores
- **NFR13:** Lifecycle rules from lifecycle.yaml only — no duplication
