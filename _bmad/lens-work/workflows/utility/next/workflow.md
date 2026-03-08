# /next — Recommend Next Action Workflow

**Phase:** Utility
**Purpose:** Determine and display the single next actionable task for the user based on git-derived lifecycle state.

## Pre-conditions

- User is on an initiative branch (or control repo with initiatives)

## Steps

### Step 1: Run /status Internally

Execute the status workflow internally (no output to user) to derive:
- Current initiative and branch
- Current phase and audience
- PR status (open, merged, closed)
- Completed phases
- Track phases remaining

### Step 2: Apply Lifecycle Rules

Read `lifecycle.yaml` to determine phase ordering for the current track. Apply rules in priority order:

**Rule 1 — Phase in progress, not complete:**
If current phase branch exists and no PR created yet:
```
▶️ Continue working on `/{current-phase}`.
   Complete the phase artifacts, then a PR will be created automatically.
```

**Rule 2 — Phase PR open, awaiting review:**
If PR from `{root}-{audience}-{phase}` → `{root}-{audience}` is open:
```
⏳ Phase `{phase}` PR is open and awaiting review.
   PR: {pr-url}
```

**Rule 3 — Phase complete, next phase available:**
If the current phase PR is merged and the next phase in the track exists:
```
▶️ Run `/{next-phase}` to start the next phase.
   Previous phase `{phase}` complete ✅
```

**Rule 4 — All phases for current audience complete, promotion available:**
If all phases for the current audience are done (PRs merged):
```
▶️ Run `/promote` to promote from `{audience}` to `{next-audience}`.
   All `{audience}` phases complete ✅
```

**Rule 5 — Promotion PR open:**
If a promotion PR is open:
```
⏳ Promotion PR `{audience}` → `{next-audience}` is open and awaiting review.
   PR: {pr-url}
```

**Rule 6 — Track fully complete:**
If the initiative has reached the final audience and all gates are passed:
```
✅ All caught up — no pending actions.
   Initiative `{initiative-root}` has completed the `{track}` lifecycle.
```

**Rule 7 — No initiative context:**
If the user is not on an initiative branch:
```
ℹ️ Not currently on an initiative branch.
   Run `/status` to see all initiatives, or `/switch` to select one.
```

### Step 3: Return ONE Directive

**Critical UX requirement:** `/next` returns exactly ONE action, not a list of options.

The response always includes:
1. The specific command to run (if applicable)
2. Brief context on why this is the next action
3. Status of what was completed before

### Step 4: Display Response

Follow the 3-part response format:

**Context Header:**
```
📂 Initiative: {initiative-root}
🏷️ Track: {track}
👥 Audience: {audience}
📋 Phase: {current-phase}
```

**Primary Content:**
The single directive from Step 2.

**Next Step:**
The command to run (or calm "all caught up" message).

## Design Principles

- `/next` is the "killer UX feature" — it removes decision fatigue
- ONE directive, not a menu of options
- "All caught up" is a positive, calm message — not an error
- Lifecycle rules come from lifecycle.yaml — never hardcode phase ordering
- Phase ordering: follows the track's `phases:` array and audience progression

## NFR Compliance

- **NFR1:** All state derived from git — no secondary state stores
- **NFR13:** Lifecycle rules from lifecycle.yaml only — no duplication
