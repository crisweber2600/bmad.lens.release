# Source-to-Release Promotion Pipeline

**Purpose:** Promote validated module source from `bmad.lens.bmad/bmad.lens.src` to `bmad.lens.release` (alpha → beta PR).

## Workflow Location

```
bmad.lens.bmad/.github/workflows/promote-to-release.yml
```

## Pipeline Flow

```
push to master (bmad.lens.src/_bmad/lens-work/**)
  │
  ├─ Validate declarative-only constraint
  ├─ Validate required files exist
  ├─ Read module version from module.yaml
  │
  ├─ Clone bmad.lens.release → checkout alpha
  ├─ Delete existing _bmad/lens-work/ contents
  ├─ Copy finalized output from bmad.lens.src/_bmad/lens-work/
  ├─ Commit & push to alpha
  │
  └─ Create PR: alpha → beta (via GitHub REST API, no gh CLI)
```

## Triggers

| Trigger | Action |
|---------|--------|
| Push to `master` changing `bmad.lens.src/_bmad/lens-work/**` | Validate + promote to alpha + open PR to beta |
| Manual `workflow_dispatch` | Same as above |

## Validation Steps

1. **Declarative-only scan** — Fail if executable files found outside `scripts/`
2. **Required files check** — Verify `lifecycle.yaml`, `module.yaml`, `module-help.csv`, `README.md` exist
3. **Version read** — Extract version from `module.yaml` for commit message and PR title

## Release Repo Structure Mapping

| Source | Release (alpha branch) |
|--------|---------|
| `bmad.lens.src/_bmad/lens-work/` | `bmad.lens.release/_bmad/lens-work/` |

### Included in promotion:
- `lifecycle.yaml`, `module.yaml`, `module-help.csv`, `README.md`
- `agents/`, `skills/`, `workflows/`, `prompts/`, `docs/`, `tests/`, `scripts/`

### Excluded from promotion:
- CI/CD workflow files (`.github/workflows/`)
- Development-only documentation
- Any disallowed executable files (hard failure)

## PR Creation

- Uses **GitHub REST API** directly (no `gh` CLI dependency)
- If an open PR from `alpha → beta` already exists, the push updates it automatically
- PR title includes module version; body includes source commit SHA and actor

## Idempotency

The pipeline is idempotent — re-running produces the same result. The `rm -rf` + `cp -r` pattern ensures:
- New files in source appear in release
- Deleted files in source are removed from release
- Modified files in source update in release

## Security

- Release repo push requires `RELEASE_REPO_TOKEN` secret (PAT with `repo` scope on `bmad.lens.release`)
- Pipeline runs as `github-actions[bot]` — no human credentials in git history
- Executable file scan enforces NFR11 at CI level
- Token is never logged; used only in `git clone` auth and API calls

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `RELEASE_REPO_TOKEN` | PAT with `repo` scope on `bmad.lens.release` — enables clone, push, and PR creation |
