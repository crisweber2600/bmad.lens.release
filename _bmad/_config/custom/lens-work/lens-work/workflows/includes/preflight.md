# Shared Preflight

**Include with:** Reference this file from any prompt that needs preflight.

**Purpose:** Ensures all authority repos are synchronized and constitutional governance is resolved before workflow execution.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `skip_constitution` | boolean | `false` | When `true`, skip Step 5 (Resolve and Enforce Constitution). Use this when the calling workflow performs its own constitutional context injection (e.g., via a dedicated Step 1a). |

---

## Preflight Steps

### 1. Check Release Branch

Read the `bmad.lens.release` branch:
```bash
git -C bmad.lens.release branch --show-current
```

### 1a. Enforce LENS_VERSION Compatibility

Read `LENS_VERSION` from the control repo root and `schema_version` from `bmad.lens.release/_bmad/lens-work/lifecycle.yaml`.

If `LENS_VERSION` is missing or does not match the lifecycle schema version, hard-stop the workflow:

```bash
MODULE_SCHEMA=$(awk '/^schema_version:/ { print $2; exit }' bmad.lens.release/_bmad/lens-work/lifecycle.yaml)

if [[ -z "$MODULE_SCHEMA" ]]; then
        echo "ERROR: Unable to determine schema_version from bmad.lens.release/_bmad/lens-work/lifecycle.yaml."
        exit 1
fi

if [[ ! -f LENS_VERSION ]]; then
        echo "VERSION MISMATCH: control repo is missing LENS_VERSION, module expects v${MODULE_SCHEMA}. Run /lens-upgrade."
        exit 1
fi

CONTROL_VERSION=$(tr -d $'\r\n' < LENS_VERSION || true)

if [[ -z "$CONTROL_VERSION" || ( "$CONTROL_VERSION" != "$MODULE_SCHEMA" && "$CONTROL_VERSION" != "$MODULE_SCHEMA.0.0" ) ]]; then
        echo "VERSION MISMATCH: control repo is v${CONTROL_VERSION:-missing}, module expects v${MODULE_SCHEMA}. Run /lens-upgrade."
        exit 1
fi
```

**PowerShell:**
```powershell
$moduleSchemaLine = Get-Content "bmad.lens.release/_bmad/lens-work/lifecycle.yaml" | Where-Object { $_ -match '^schema_version:' } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($moduleSchemaLine)) {
    throw "VERSION MISMATCH: lifecycle.yaml is missing a 'schema_version:' entry. Run /lens-upgrade."
}

$moduleSchema = ($moduleSchemaLine -split ':', 2)[1].Trim()

if ([string]::IsNullOrWhiteSpace($moduleSchema)) {
    throw "VERSION MISMATCH: lifecycle.yaml has an empty 'schema_version'. Run /lens-upgrade."
}

$controlVersion = if (Test-Path "LENS_VERSION") { (Get-Content "LENS_VERSION" -Raw).Trim() } else { "" }

if ([string]::IsNullOrWhiteSpace($controlVersion) -or ($controlVersion -ne $moduleSchema -and $controlVersion -ne "$moduleSchema.0.0")) {
                $displayControlVersion = if ([string]::IsNullOrWhiteSpace($controlVersion)) { 'missing' } else { $controlVersion }
                throw "VERSION MISMATCH: control repo is v$displayControlVersion, module expects v$moduleSchema. Run /lens-upgrade."
}
```

### 2. Determine Pull Strategy

Read `_bmad-output/lens-work/personal/.preflight-timestamp` as the last successful full preflight time (ISO 8601 UTC datetime).

Use branch-aware freshness windows:
- **If branch is `alpha`:** run full preflight when timestamp is missing or older than **1 hour**.
- **If branch is `beta`:** run full preflight when timestamp is missing or older than **3 hours**.
- **Otherwise:** run full preflight when timestamp is missing or older than **today** (daily cadence).

If full preflight is required, pull ALL authority repos:

```bash
git -C bmad.lens.release pull origin
git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
```

If full preflight is not required, skip pulls and run presence + `.github` sync checks only.

### 3. Sync .github from Release Repo

On every preflight run, verify `.github/` completeness against `bmad.lens.release/.github/` and sync if files are missing. Also sync if release `.github/` changed during pull.

This check runs even when pull is skipped by timestamp.

If `bmad.lens.release/.github/` is missing, stop with an error.

If `.github/` is missing, create it and copy from release.

If any files are missing in local `.github/`, copy from release.

If pull detected changes under release `.github/`, copy from release.

After sync, keep prompt hygiene: `.github/prompts/` must only contain `lens-work*.prompt.md` files.

**PowerShell:**
```powershell
if (-not (Test-Path "bmad.lens.release/.github")) {
        throw "Missing authority folder: bmad.lens.release/.github"
}

if (-not (Test-Path ".github")) {
        New-Item -ItemType Directory -Path ".github" -Force | Out-Null
        Copy-Item -Recurse -Force "bmad.lens.release/.github/*" ".github/"
}

$missing = Get-ChildItem "bmad.lens.release/.github" -Recurse -File |
        Where-Object {
                $relative = $_.FullName.Substring((Resolve-Path "bmad.lens.release/.github").Path.Length).TrimStart('\\','/')
                -not (Test-Path (Join-Path ".github" $relative))
        }

$changed = git -C bmad.lens.release diff --name-only HEAD@{1} HEAD -- .github/ 2>$null

if ($missing.Count -gt 0 -or $changed) {
        Copy-Item -Recurse -Force "bmad.lens.release/.github/*" ".github/"
}

if (Test-Path ".github/prompts") {
        Get-ChildItem ".github/prompts" -File -Filter "*.prompt.md" |
                Where-Object { $_.Name -notlike "lens-work*.prompt.md" } |
                Remove-Item -Force
}
```

**Bash:**
```bash
if [ ! -d "bmad.lens.release/.github" ]; then
    echo "ERROR: Missing authority folder bmad.lens.release/.github"
    exit 1
fi

if [ ! -d ".github" ]; then
    mkdir -p .github
    cp -rf bmad.lens.release/.github/* .github/
fi

missing="$(cd bmad.lens.release && find .github -type f | while read -r f; do [ -f "../$f" ] || echo "$f"; done)"
changed="$(git -C bmad.lens.release diff --name-only HEAD@{1} HEAD -- .github/ 2>/dev/null || true)"

if [ -n "$missing" ] || [ -n "$changed" ]; then
    cp -rf bmad.lens.release/.github/* .github/
fi

if [ -d ".github/prompts" ]; then
    find .github/prompts -type f -name '*.prompt.md' ! -name 'lens-work*.prompt.md' -delete
fi
```

### 4. Verify Authority Repos

If any authority repo directory is missing, stop and report the failure.

**Exception for /onboard:** If missing repos are reported during onboarding, continue so the workflow can bootstrap/repair those repos.

### 5. Resolve and Enforce Constitution

> **Skippable:** When `params.skip_constitution == true`, skip this entire step and proceed to Step 6.
> Callers that perform their own constitutional context injection (e.g., router workflows with a dedicated Step 1a)
> MUST pass `skip_constitution: true` to avoid double-resolution. The constitution skill's `resolve-context`
> operation returns the session-cached result on second call, but the gate enforcement below does NOT re-run from cache —
> skipping here is the clean approach.

Resolve constitutional governance before any workflow-specific logic runs.

```yaml
if params.skip_constitution != true:
  # Resolve constitutional context (initiative-aware when available, global fallback otherwise)
  constitutional_context = invoke("constitution.resolve-context")

  if constitutional_context.status == "parse_error":
          # Bootstrap workflows (for example /onboard, /new-domain) may not have
          # initiative-level context yet. Downgrade to advisory in that case.
          if constitutional_context.context_available == false:
                  warning: "⚠️ Constitutional context unavailable during bootstrap. Continuing in advisory mode."
                  constitutional_context.gate_mode = "advisory"
          else:
                  FAIL("❌ Constitutional context parse error. Fix governance files before continuing.")

  session.constitutional_context = constitutional_context

  # Enforce hard-gate mode immediately when constitution requires it
  if constitutional_context.gate_mode == "hard" and constitutional_context.preflight_status == "FAIL":
          FAIL("❌ Constitution hard gate failed during preflight. Resolve compliance issues before running this workflow.")

  # Advisory mode never blocks, but must be surfaced to the user
  if constitutional_context.gate_mode == "advisory" and constitutional_context.preflight_status == "WARN":
          warning: "⚠️ Constitution advisory warnings detected. Continue with care and address warnings in phase outputs."
```

All downstream workflow decisions MUST follow `session.constitutional_context`.

### 6. Update Timestamp

After a successful full preflight, write the current UTC timestamp (ISO 8601 datetime) to `_bmad-output/lens-work/personal/.preflight-timestamp`.

---

## Authority Repos

| Repo | Purpose |
|------|---------|
| `bmad.lens.release` | Release module with workflows, agents, prompts |
| `{governance-repo-path}` | Governance settings (from `_bmad-output/lens-work/governance-setup.yaml`) |

## Synced Content

| Source | Destination | Content |
|--------|-------------|---------|
| `bmad.lens.release/.github/` | `.github/` | Copilot agents, prompts, instructions |
