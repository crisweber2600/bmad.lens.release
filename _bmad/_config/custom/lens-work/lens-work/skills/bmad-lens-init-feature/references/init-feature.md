# Init Feature Flow

Initialize a new feature with 2-branch topology, feature.yaml, governance index entry, and PR.

## Outcome

After this flow completes:

- Branches `{featureId}` and `{featureId}-plan` exist in the control repo
- `feature.yaml` exists at `{governance-repo}/features/{domain}/{service}/{featureId}/feature.yaml` on the `{featureId}-plan` branch
- `feature-index.yaml` on `main` has a new entry for `{featureId}`
- `summary.md` stub exists at `{governance-repo}/features/{domain}/{service}/{featureId}/summary.md` on `main`
- A PR exists from `{featureId}-plan` → `{featureId}` titled "Planning: {feature name}"

## Process

### Step 1: Gather Inputs

Prompt for (if not already provided):

1. **Feature name** — human-readable, used to derive featureId (e.g., "Auth Token Refresh" → `auth-refresh`)
2. **Domain** — organizational domain (e.g., `platform`, `commerce`)
3. **Service** — service within the domain (e.g., `identity`, `payments`)

Derive:

- **featureId** — slugify the feature name: lowercase, replace spaces with `-`, strip non-alphanumeric
- **track** — from `{default_track}` in user-profile.md or config (default: `quickplan`)
- **username** — from `{username}` resolved on activation

Confirm the derived featureId with the user before proceeding.

### Step 2: Validate with Dry Run

```bash
python3 ./scripts/init-feature-ops.py create \
  --governance-repo {governance_repo} \
  --control-repo {control_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service} \
  --name "{feature name}" \
  --track {track} \
  --username {username} \
  --dry-run
```

If validation fails, report the error and prompt for correction. Do not proceed until validation passes.

### Step 3: Create Files and Get Git Commands

```bash
python3 ./scripts/init-feature-ops.py create \
  --governance-repo {governance_repo} \
  --control-repo {control_repo} \
  --feature-id {featureId} \
  --domain {domain} \
  --service {service} \
  --name "{feature name}" \
  --track {track} \
  --username {username}
```

The script:

1. Creates `feature.yaml` at `{governance-repo}/features/{domain}/{service}/{featureId}/feature.yaml`
2. Adds an entry to `{governance-repo}/feature-index.yaml` (creates if absent)
3. Creates `{governance-repo}/features/{domain}/{service}/{featureId}/summary.md` stub
4. Returns `git_commands` and `gh_commands` arrays in the JSON output

### Step 4: Execute Git and GitHub Commands

Execute the `git_commands` returned by the script in sequence, then the `gh_commands`:

```bash
# Each command in git_commands runs in order
# Example output sequence:
# git -C {control_repo} checkout -b {featureId}
# git -C {control_repo} checkout -b {featureId}-plan
# git -C {governance_repo} checkout -b {featureId}-plan
# git -C {governance_repo} add features/{domain}/{service}/{featureId}/feature.yaml
# git -C {governance_repo} commit -m "feat({domain}/{service}): init {featureId} planning artifacts"
# git -C {governance_repo} checkout main
# git -C {governance_repo} add feature-index.yaml features/{domain}/{service}/{featureId}/summary.md
# git -C {governance_repo} commit -m "feat: add {featureId} to feature index"

# Then gh_commands:
# gh pr create --repo {control_repo} --head {featureId}-plan --base {featureId} ...
```

### Step 5: Confirm Initialization

Present the initialization summary to the user:

| Field | Value |
|-------|-------|
| Feature ID | `{featureId}` |
| Feature Branch | `{featureId}` |
| Plan Branch | `{featureId}-plan` |
| Feature YAML | `features/{domain}/{service}/{featureId}/feature.yaml` |
| PR | Planning: {feature name} (`{featureId}-plan` → `{featureId}`) |
| Index | `feature-index.yaml` ✓ |
| Summary | `features/{domain}/{service}/{featureId}/summary.md` ✓ |

Offer to run **Auto-Context Pull** to load domain context before handing off to planning.
