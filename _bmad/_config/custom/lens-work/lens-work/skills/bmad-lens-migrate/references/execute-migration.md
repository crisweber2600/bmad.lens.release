# Execute Migration

Execute the migration plan after dry-run confirmation. Creates new branch artifacts, populates feature-index.yaml, and writes summary stubs on main.

## Outcome

For each confirmed feature:
- `feature.yaml` created at `{governance_repo}/features/{domain}/{service}/{featureId}/feature.yaml`
- Entry added to `{governance_repo}/feature-index.yaml`
- Summary stub created at `{governance_repo}/summaries/{featureId}.md`

Old branches are NOT deleted at this step. Cleanup is a separate, explicit operation.

## Pre-execution Checklist

1. Dry-run has been shown to the user ✓
2. User has confirmed the migration ✓
3. Conflicts have been reviewed and resolved or skipped ✓

## Execute Single Feature

```bash
python3 ./scripts/migrate-ops.py migrate-feature \
  --governance-repo {governance_repo} \
  --old-id {old_id} \
  --feature-id {feature_id} \
  --domain {domain} \
  --service {service} \
  --username {username}
```

## Output Shape

```json
{
  "status": "pass",
  "feature_id": "auth-login",
  "dry_run": false,
  "feature_yaml_created": true,
  "index_updated": true,
  "summary_created": true
}
```

## Execution Loop

For each confirmed feature in the migration plan:

1. Run `check-conflicts` — if conflict detected, skip and log
2. Read `initiative-state.yaml` from legacy branch (state-preserving conversion)
3. Run `migrate-feature` (live, no `--dry-run`)
4. Scaffold governance feature directory:
   - Create `{governance_repo}/features/{domain}/{service}/{featureId}/`
   - Create `problems.md` from template if not exists
   - Copy planning artifacts from legacy branches to governance feature directory
5. Log result: pass / fail / skipped
6. Continue to next feature — do not abort batch on single failure

### Governance Directory Scaffolding (v3.4)

After feature.yaml is created, scaffold the governance feature directory:

```yaml
feature_dir = "{governance_repo}/features/{domain}/{service}/{featureId}"
ensure_directory(feature_dir)

# Create problems.md from template
problems_template = load("../../assets/templates/problems-template.md")
write_if_not_exists("${feature_dir}/problems.md", render(problems_template, {
  featureId: featureId,
  domain: domain,
  service: service,
  created_date: now()
}))

# Copy planning artifacts from legacy branches to governance
legacy_docs = git_ls_tree("origin/${old_id}", "_bmad-output/lens-work/planning-artifacts/")
for doc in legacy_docs:
  content = git_show("origin/${old_id}:${doc.path}")
  write_file("${feature_dir}/${doc.name}", content)
```

## feature.yaml Structure

The created feature.yaml follows the Lens Next schema. v3.4 enhancement: when
`initiative-state.yaml` exists on a legacy branch, state is preserved during migration
rather than defaulting to `preplan`.

### State-Preserving Conversion (v3.4)

Before creating feature.yaml, attempt to read existing state:

```yaml
# Try to load initiative-state from the legacy root branch
legacy_state = git_show("origin/${old_id}:_bmad-output/lens-work/initiatives/${domain}/${service}/initiative-state.yaml")

if legacy_state != null:
  # Preserve actual lifecycle state
  current_phase = legacy_state.current_phase || "preplan"
  current_milestone = legacy_state.current_milestone || null
  track = legacy_state.track || "full"
  artifacts = legacy_state.artifacts || {}
  phase_transitions = legacy_state.phase_transitions || []
else:
  # Fallback to defaults when no state file exists
  current_phase = "preplan"
  current_milestone = null
  track = "full"
  artifacts = {}
  phase_transitions = [{ phase: "preplan", timestamp: now(), user: username }]
```

Resulting feature.yaml:

```yaml
featureId: auth-login
name: Auth Login
description: Migrated from legacy branch: platform-identity-auth-login
domain: platform
service: identity
phase: ${current_phase}       # Preserved from initiative-state.yaml or defaults to preplan
track: ${track}               # Preserved from initiative-state.yaml or defaults to full
priority: medium
created: <timestamp>
updated: <timestamp>
team:
  - username: {username}
    role: lead
phase_transitions: ${phase_transitions}  # Preserved from initiative-state.yaml
artifacts: ${artifacts}                  # Preserved from initiative-state.yaml
migrated_from: platform-identity-auth-login
topology: "2-branch"
branches:
  root: auth-login
  plan: auth-login-plan
```

## feature-index.yaml Entry

Added entry format:

```yaml
features:
  - featureId: auth-login
    domain: platform
    service: identity
    migrated_from: platform-identity-auth-login
    added: <timestamp>
```

## Summary Stub (summaries/{featureId}.md)

Written to main branch at `{governance_repo}/summaries/{featureId}.md`:

```markdown
# Auth Login

**Feature ID:** auth-login
**Domain:** platform
**Service:** identity
**Migrated from:** platform-identity-auth-login
**Migration date:** <timestamp>

## Summary

_To be filled in._
```

## Completion Summary

After all features are processed, show:

```
Migration complete:
  ✓ N features migrated successfully
  ✗ N features failed (see errors above)
  ⚠ N features skipped (conflicts)

Old branches preserved. To remove them, run cleanup explicitly.
```

## Cleanup Step

Cleanup is a **separate, explicit operation** and must never happen automatically.

Only run cleanup after:
1. Migration has completed successfully
2. New branches and feature.yaml files have been verified
3. User explicitly confirms: "Delete old branches? (yes/no)"

Cleanup deletes the directories under `{governance_repo}/branches/` for migrated features only. Failed or skipped features are not cleaned up.
