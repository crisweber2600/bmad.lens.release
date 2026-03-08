# /new-domain, /new-service, /new-feature — Init Initiative Workflow

**Phase:** Router
**Purpose:** Create a new initiative with proper branch topology, validated naming, and cross-initiative sensing.
**Covers:** `/new-domain`, `/new-service`, `/new-feature`

## Pre-conditions

- User is authenticated and onboarded (`profile.yaml` exists)
- Control repo is a git repository with a remote configured
- `lifecycle.yaml` is accessible in the lens-work module

## Steps

### Step 1: Determine Scope and Collect Parameters

Read the command to determine scope:

| Command | Scope | Required Parameters |
|---------|-------|---------------------|
| `/new-domain` | domain | domain name, feature name, track |
| `/new-service` | service | domain name, service name, feature name, track |
| `/new-feature` | feature | domain name, service name, feature name, track |

Collect missing parameters from the user. Present track options from `lifecycle.yaml`:

| Track | Description | Phases |
|-------|-------------|--------|
| `full` | Complete lifecycle — all phases, all audiences | preplan → businessplan → techplan → devproposal → sprintplan |
| `feature` | Known business context — skip research | businessplan → techplan → devproposal → sprintplan |
| `tech-change` | Pure technical change | techplan → sprintplan |
| `hotfix` | Urgent fix — minimal planning | techplan |
| `spike` | Research only — no implementation | preplan |
| `quickdev` | Rapid execution — delegates to target agents | devproposal |

### Step 2: Validate Names (Slug-Safe Enforcement)

Apply slug-safe validation to all name components (domain, service, feature):

**Rules:**
- Lowercase alphanumeric characters and hyphens only
- No leading or trailing hyphens
- No consecutive hyphens
- 2-50 characters length
- Must not conflict with reserved tokens: `small`, `medium`, `large`, `base`
- Must not conflict with phase names: `preplan`, `businessplan`, `techplan`, `devproposal`, `sprintplan`, `dev`

**If invalid:** Reject with explanation and suggest correction.
```
❌ Name "My Feature!" is not slug-safe.
   Suggested: "my-feature"
   Rules: lowercase, alphanumeric, hyphens only, no leading/trailing hyphens.
```

### Step 3: Derive Initiative Root

| Scope | Initiative Root | Config Path |
|-------|-----------------|-------------|
| domain | `{domain}-{feature}` | `_bmad-output/lens-work/initiatives/{domain}/{feature}.yaml` |
| service | `{domain}-{service}-{feature}` | `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml` |
| feature | `{domain}-{service}-{feature}` | `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml` |

### Step 4: Read lifecycle.yaml

Load `lifecycle.yaml` and validate:
- The selected track exists in the `tracks:` section
- Extract the phases and audiences enabled by this track
- Determine the start phase from `start_phase:` field

### Step 5: Cross-Initiative Sensing (Pre-Creation)

**BEFORE creating any branches**, run cross-initiative sensing:

1. List all existing initiative branches:
   ```bash
   git branch --list '*-small*' '*-medium*' '*-large*' | sed -E 's/-(small|medium|large|base)(-.*)?$//' | sort -u
   ```

2. Parse branch names to find initiatives in the same domain (or service):
   - Same domain: branches starting with `{domain}-`
   - Same service: branches starting with `{domain}-{service}-`

3. For each overlapping initiative, report:
   ```
   ⚠️ Active initiatives in domain `{domain}`:
   - `{initiative-1}` (techplan/small)
   - `{initiative-2}` (devproposal/medium)
   Review for potential conflicts.
   ```

4. **Default behavior:** Informational gate — warn and continue.
5. **If constitution upgrades to hard gate:** Block creation and report why.

### Step 6: Verify Track Permissions

Check governance repo (if available) to verify the selected track is permitted at this LENS hierarchy level. If governance repo is not accessible, proceed with a warning.

### Step 7: Create Initiative Config

Create the initiative config YAML file:

```yaml
# Initiative configuration — committed to git (Domain 1 artifact)
initiative: {feature}
domain: {domain}
service: {service}          # omitted for domain scope
track: {track}
language: unknown           # auto-detected later or user-specified
created: {ISO8601}
initiative_root: {initiative-root}
```

Path: `_bmad-output/lens-work/initiatives/{domain}/[{service}/]{feature}.yaml`

### Step 8: Create Branch Topology

Using the git-orchestration skill:

1. Create initiative root branch from the control repo default branch:
   ```bash
   git checkout {default-branch}
   git checkout -b {initiative-root}
   ```

2. Create first audience branch from root:
   ```bash
   git checkout -b {initiative-root}-small
   ```

3. **CRITICAL: Do NOT create medium, large, or base branches.** Lazy creation — these are created on-demand at promotion time.

### Step 9: Commit and Push

Using the git-orchestration skill:

1. Commit the initiative config:
   ```bash
   git add _bmad-output/lens-work/initiatives/{path}/{feature}.yaml
   git commit -m "[INIT] {initiative-root} — initiative created (track: {track})"
   ```

2. Push both branches:
   ```bash
   git push -u origin {initiative-root}
   git push -u origin {initiative-root}-small
   ```

### Step 10: Display Response

Follow the 3-part response format:

**Context Header:**
```
📂 Initiative: {initiative-root}
🏷️ Track: {track}
👥 Audience: small
📋 Phases: {phase-list}
```

**Primary Content:**
```
✅ Initiative created successfully.

Branch topology:
- `{initiative-root}` (root)
- `{initiative-root}-small` (active)

Config committed at:
  `_bmad-output/lens-work/initiatives/{path}/{feature}.yaml`
```

**Next Step:**
```
▶️ Run `/{start-phase}` to begin the first phase.
```

Where `{start-phase}` is the track's `start_phase` from lifecycle.yaml.

## Error Handling

| Error | Response |
|-------|----------|
| Invalid track | "Track `{input}` not found. Available tracks: full, feature, tech-change, hotfix, spike, quickdev." |
| Slug-unsafe name | Reject with explanation and suggested correction |
| Initiative already exists | "Initiative `{root}` already exists. Use `/switch {root}` to resume." |
| Not authenticated | "Run `/onboard` first to authenticate." |
| Sensing hard gate failure | "⚠️ Constitution blocks creation: {reason}. Contact governance admin." |
