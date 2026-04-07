# Shared Preflight

**Include with:** Reference this file from any prompt that needs preflight.

**Purpose:** Ensures all authority repos are synchronized and constitutional governance is resolved before workflow execution.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip_constitution` | boolean | `false` | When `true`, skip Step 5 (Resolve and Enforce Constitution). Use this when the calling workflow performs its own constitutional context injection (e.g., via a dedicated Step 1a). |

---

## Preflight Steps

> **Script implementation:** The full logic for Steps 1–4b is implemented in
> [`scripts/preflight.sh`](../../scripts/preflight.sh) (Bash) and
> [`scripts/preflight.ps1`](../../scripts/preflight.ps1) (PowerShell).
> The steps below describe the algorithm. Run the script to execute all checks:
>
> ```bash
> bash {release_repo_root}/lens.core/_bmad/lens-work/scripts/preflight.sh                    # default
> bash {release_repo_root}/lens.core/_bmad/lens-work/scripts/preflight.sh --caller onboard   # from /onboard
> bash {release_repo_root}/lens.core/_bmad/lens-work/scripts/preflight.sh --skip-constitution
> ```
>
> ```powershell
> .\{release_repo_root}\lens.core\_bmad\lens-work\scripts\preflight.ps1                      # default
> .\{release_repo_root}\lens.core\_bmad\lens-work\scripts\preflight.ps1 -Caller onboard      # from /onboard
> .\{release_repo_root}\lens.core\_bmad\lens-work\scripts\preflight.ps1 -SkipConstitution
> ```

### 1. Check Release Branch

Verify that `{release_repo_root}` directory exists.

### 1a. Enforce LENS_VERSION Compatibility

Read `LENS_VERSION` from the control repo root and `schema_version` from `{release_repo_root}/lens.core/_bmad/lens-work/lifecycle.yaml`. If they don't match, show a diagnostic and hard-stop:

```
❌ LENS_VERSION mismatch

  Control repo LENS_VERSION:  {control_repo_version}
  Release module schema_version: {release_schema_version}

Your control repo was created for a different module version.
Run /lens-upgrade to migrate your control repo to the latest schema.
```

> **Session caching:** The agent activation (step 4) loads `lifecycle.yaml` into `{lifecycle}`. If the session variable `{lifecycle}` already contains the parsed lifecycle data, use it instead of re-reading the file. Fall back to a file read only on cache-miss.

### 2. Determine Pull Strategy

> See [docs/preflight-strategy.md](../../docs/preflight-strategy.md) for rationale behind freshness windows.

Read `_bmad-output/lens-work/personal/.preflight-timestamp` as the last successful full preflight time (ISO 8601 UTC datetime).

Use branch-aware freshness windows:
- **If branch is `alpha`:** run full preflight when timestamp is missing or older than **1 hour**.
- **If branch is `beta`:** run full preflight when timestamp is missing or older than **3 hours**.
- **Otherwise:** run full preflight when timestamp is missing or older than **today** (daily cadence).

If full preflight is required, pull ALL authority repos. Otherwise, skip pulls and run presence + `.github` sync checks only.

### 3. Sync .github from Release Repo

On every preflight run, verify `.github/` completeness against `{release_repo_root}/.github/` and sync if files are missing. Also sync if release `.github/` changed during pull. Keep prompt hygiene: `.github/prompts/` must only contain `lens-work*.prompt.md` files.

### Step 3b: Sync Agent Entry Points

On every preflight run, sync agent entry point files (e.g., `CLAUDE.md`) from the release repo to the workspace root. Copy each entry point file if it is missing or if the release version changed during pull.

### Step 4: Verify IDE Adapters

On every preflight run, check that IDE command adapters are installed. For Claude Code, the required adapter is `.claude/commands/`. If the directory is missing, run the installer in idempotent mode before proceeding.

Note: If additional IDEs are active (Cursor, Codex), add equivalent checks as those adapters are introduced to the workspace.

### 4. Verify Authority Repos

If any authority repo directory is missing:

1. **If the calling workflow is `/onboard`:** Continue so the workflow can bootstrap/repair those repos.
2. **Otherwise:** Show a warm redirect instead of a cryptic hard-stop — explain what onboarding does, how long it takes, and offer to run `/onboard`.

### 5. Resolve and Enforce Constitution

> **Skippable:** When `params.skip_constitution == true`, skip this entire step and proceed to Step 6.
> Callers that perform their own constitutional context injection (e.g., router workflows with a dedicated Step 1a)
> MUST pass `skip_constitution: true` to avoid double-resolution. The constitution skill's `resolve-context`
> operation returns the session-cached result on second call, but the gate enforcement below does NOT re-run from cache —
> skipping here is the clean approach.

Resolve constitutional governance before any workflow-specific logic runs.

#### 5a. Validate Branch State

```yaml
if params.skip_constitution == true:
  # Skip — caller handles its own constitutional context injection
  goto: Step 6

# Before resolving constitution, verify we're on the expected initiative branch.
# Mid-initiative workflows that modify lifecycle state must be on the correct branch
# to ensure constitution resolution reads the right governance context.

current_branch = invoke_command("git symbolic-ref --short HEAD")
expected_branch = session.initiative_root || null

if expected_branch != null and current_branch != expected_branch:
  warning: |
    ⚠️ Branch mismatch detected.
    Current branch:  ${current_branch}
    Expected branch: ${expected_branch}

    Constitution resolution may return stale or incorrect governance rules
    if performed from the wrong branch.

  ask: "Switch to '${expected_branch}' before continuing? (yes/no)"
  capture: switch_branch
  if lower(switch_branch) == "yes":
    invoke: git-orchestration.checkout-branch
    params:
      branch: ${expected_branch}
    invoke: git-orchestration.pull-latest
  else:
    warning: "Continuing on '${current_branch}' — governance rules may not match initiative context."
```

#### 5b. Resolve Context

# Check session cache first — avoid re-resolving if already loaded during this session
if session.constitutional_context exists and session.constitutional_context.status != null:
  constitutional_context = session.constitutional_context
else:
  constitutional_context = invoke("constitution.resolve-context")
```

#### 5c. Handle Parse Errors

```yaml
if constitutional_context.status == "parse_error":
  if constitutional_context.context_available == false:
    warning: "⚠️ Constitutional context unavailable during bootstrap. Continuing in advisory mode."
    constitutional_context.gate_mode = "advisory"
  else:
    FAIL("❌ Constitutional context parse error. Fix governance files before continuing.")
```

#### 5d. Cache and Enforce Hard Gates

```yaml
session.constitutional_context = constitutional_context

if constitutional_context.gate_mode == "hard" and constitutional_context.preflight_status == "FAIL":
  FAIL("❌ Constitution hard gate failed during preflight. Resolve compliance issues before running this workflow.")
```

#### 5e. Surface Advisory Warnings

```yaml
if constitutional_context.gate_mode == "advisory" and constitutional_context.preflight_status == "WARN":
  warning: "⚠️ Constitution advisory warnings detected. Continue with care and address warnings in phase outputs."
```

All downstream workflow decisions MUST follow `session.constitutional_context`.

### 6. Update Timestamp

After a successful full preflight, write the current UTC timestamp (ISO 8601 datetime) to `_bmad-output/lens-work/personal/.preflight-timestamp`.

### 7. Load Cross-Feature Context *(v3.3)*

> **Conditional:** Only runs when `features_registry.enabled == true` in lifecycle.yaml
> AND the current branch resolves to a known initiative (not main, develop, or non-initiative branches).

After constitution resolution and timestamp update, load cross-feature context so all
downstream workflow steps have awareness of related features, dependencies, and blockers.

```yaml
features_registry_config = load("lifecycle.yaml").features_registry
if not features_registry_config.enabled:
  # Feature registry not enabled — skip cross-feature context
  session.cross_feature_context = { status: "disabled" }
  goto: end

# Resolve current initiative
current_initiative = invoke: git-state.current-initiative
if current_initiative is null:
  # Not on an initiative branch — skip
  session.cross_feature_context = { status: "not_applicable", reason: "not on initiative branch" }
  goto: end

# 7a. Fetch cross-feature context
cross_context = invoke: git-state.cross-feature-context
params:
  initiative_root: ${current_initiative.initiative_root}

session.cross_feature_context = cross_context

# 7b. Surface staleness warnings
if cross_context.staleness.is_stale == true:
  stale_list = cross_context.staleness.stale_features.join(', ')
  warning: |
    ⚠️ Cross-feature context is stale.
    Features updated since last context pull: ${stale_list}
    Related features may have made decisions that affect this initiative.
    Run /refresh-context to update.

# 7c. Surface dependency warnings
if cross_context.relationships.depends_on.length > 0:
  for dep in cross_context.relationships.depends_on:
    if dep.status == "unknown":
      warning: "⚠️ Dependency '${dep.feature}' not found in feature-index.yaml"

# 7d. Update context.last_pulled in initiative-state.yaml
invoke: git-orchestration.update-context-pulled
params:
  initiative_root: ${current_initiative.initiative_root}
  last_pulled: now_iso8601()
```

### 8. Load feature.yaml State *(v3.4)*

> **Conditional:** Only runs when the current initiative's track has `feature_yaml: true`
> in lifecycle.yaml AND feature.yaml exists on the current branch.

When present, feature.yaml becomes the preferred state source over git-derived state.
Downstream workflows should check `session.feature_yaml_state.available` before using
git-derived milestone/phase state.

```yaml
lifecycle = session.lifecycle || load("lifecycle.yaml")
current_initiative = invoke: git-state.current-initiative
if current_initiative is null:
  session.feature_yaml_state = { available: false, reason: "not on initiative branch" }
  goto: end

track_config = lifecycle.tracks[current_initiative.track] || {}
if track_config.feature_yaml != true:
  session.feature_yaml_state = { available: false, reason: "track does not support feature.yaml" }
  goto: end

# Check if feature.yaml exists on the current branch
feature_yaml_content = read_file_if_exists("feature.yaml")
if feature_yaml_content is null:
  session.feature_yaml_state = { available: false, reason: "feature.yaml not found on branch" }
  goto: end

session.feature_yaml_state = {
  available: true,
  topology: track_config.topology || "legacy",
  feature: feature_yaml_content.feature,
  status: feature_yaml_content.status,
  current_milestone: feature_yaml_content.current_milestone,
  current_phase: feature_yaml_content.current_phase,
  owner: feature_yaml_content.owner,
  updated_at: feature_yaml_content.updated_at,
  raw: feature_yaml_content
}
```

---

## Authority Repos

| Repo | Purpose |
|------|---------|
| `{release_repo_root}` | Release module with workflows, agents, prompts |
| `{governance-repo-path}` | Governance settings (from `_bmad-output/lens-work/governance-setup.yaml`) |

## Synced Content

| Source | Destination | Content |
|--------|-------------|---------|
| `{release_repo_root}/.github/` | `.github/` | Copilot agents, prompts, instructions |
| `{release_repo_root}/CLAUDE.md` | `./CLAUDE.md` | Claude Code agent entry point |

---

## OUTPUT CONTRACT — Context Propagation

After preflight completes, the following session variables are guaranteed to be set and available to all downstream workflow steps:

```yaml
session.constitutional_context:
  status: "ok" | "parse_error" | "unavailable"
  gate_mode: "hard" | "advisory" | "informational"
  preflight_status: "PASS" | "WARN" | "FAIL"

# v3.3: Cross-feature context (when features_registry.enabled)
session.cross_feature_context:
  status: "ok" | "disabled" | "not_applicable" | "unavailable"
  feature: "{current_feature}"
  relationships:
    depends_on: [...]               # full planning docs for hard dependencies
    blocks: [...]                   # full planning docs for blocked features
    related: [...]                  # summaries only for loosely related
  staleness:
    is_stale: true | false
    stale_features: [...]           # features updated since last context pull
  resolved_constitution: { ... }  # Full constitution hierarchy
  context_available: true | false

session.preflight_result:
  remote_url: "https://github.com/org/repo"       # Git remote URL
  provider: "github" | "azure-devops" | "gitlab"   # Detected provider
  auth_status: "authenticated" | "anonymous"        # Auth state
  sync_status: "synced" | "stale" | "failed"        # Repo sync outcome
  timestamp: "2026-04-01T12:00:00Z"                 # ISO 8601

# v3.4: feature.yaml state (when track supports feature_yaml)
session.feature_yaml_state:
  available: true | false
  topology: "legacy" | "2-branch"               # Track topology
  feature: "{feature_id}"
  status: "draft" | "planning" | "dev" | ...
  current_milestone: "techplan" | ...
  current_phase: "preplan" | ...
  owner: "{username}"
  updated_at: "2026-04-01T12:00:00Z"
  raw: { ... }                                  # Full feature.yaml contents
```

**Usage pattern:** Downstream workflows that need remote URL or provider info should reference `session.preflight_result` rather than re-deriving these values:

```yaml
# In any workflow step after preflight:
remote = session.preflight_result.remote_url
provider = session.preflight_result.provider

# Example: conditional behavior per provider
if provider == "azure-devops":
  pr_api = "azure"
else:
  pr_api = "github"
```
