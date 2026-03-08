# /status — Initiative Status Report Workflow

**Phase:** Utility
**Purpose:** Produce a consolidated status report across all active initiatives by scanning git branch topology and PR states.

## Pre-conditions

- Control repo is a git repository with a remote configured

## Steps

### Step 1: Scan Initiative Branches

Use the git-state skill to list all initiative roots:

```bash
git branch -a | sed -E 's/-(small|medium|large|base)(-.*)?$//' | sort -u
```

Filter out non-initiative branches (main, develop, feature/, etc.).

**If no initiatives found:** Display empty state and exit:
```
ℹ️ No active initiatives.

Get started:
  `/new-domain {name}`  — Create a domain-level initiative
  `/new-service {domain}/{service}` — Create a service-level initiative
```

### Step 2: Derive State Per Initiative

For each initiative root, use the git-state skill to derive:

1. **Current audience:** Parse highest audience branch that exists.
   ```bash
   git branch --list '{root}-base' '{root}-large' '{root}-medium' '{root}-small'
   ```

2. **Current phase:** Find the active phase branch (most recent, or with open PR).
   ```bash
   git branch --list '{root}-{audience}-*'
   ```

3. **Open PRs:** Use provider adapter to query PRs:
   - Phase PRs: `{root}-{audience}-{phase}` → `{root}-{audience}`
   - Promotion PRs: `{root}-{audience}` → `{root}-{next-audience}`

4. **Pending action:** Apply lifecycle rules:
   - Phase branch exists, no PR → "Complete phase"
   - PR open, not reviewed → "Awaiting review"
   - PR merged, next phase exists → "Start next phase"
   - All phases done → "Ready to promote"

### Step 3: Load Initiative Configs

For each initiative, read its config to get domain, service, and track:

```bash
git show {root}:_bmad-output/lens-work/initiatives/{domain}/[{service}/]{feature}.yaml
```

Use cross-branch reads (no checkout required).

### Step 4: Determine Current Initiative

Check what branch the user is currently on:

```bash
git symbolic-ref --short HEAD
```

Parse to extract current initiative root (if on an initiative branch).

### Step 5: Format Status Table

Render a table with ≤5 columns for narrow chat panel compatibility:

```
📊 Initiative Status Report

| Initiative | Phase | Audience | PRs | Action |
|------------|-------|----------|-----|--------|
| ► foo-auth | techplan | small | 0 | Continue phase |
| bar-api | businessplan | small | 1 ⏳ | Awaiting review |
| baz-widget | — | medium | 0 | Start devproposal |

► = current initiative
```

**Status indicators:**
- ✅ Phase complete (PR merged)
- ⏳ PR open / in review
- ❌ Blocked (prerequisite not met)
- ⚠️ Needs attention (stale PR, conflict)

### Step 6: Display Detailed View (Optional)

If user requests detail (or only one initiative exists), show expanded view:

```
📂 Initiative: foo-bar-auth
🏷️ Track: full
👥 Audience: small
📋 Completed Phases: preplan ✅, businessplan ✅
⏳ Current Phase: techplan (in progress)
📝 Open PRs: none
🔄 Pending: Complete techplan artifacts

▶️ Continue working on `/techplan`
```

## Response Format

Follow the UX spec Direction B (Structured Report Style):
- Summary table by default
- Detail on request or single-initiative context
- ≤5 table columns
- Status emoji supplements text labels (not sole indicator)

## NFR Compliance

- **NFR1:** All state derived from git — no secondary state stores queried
