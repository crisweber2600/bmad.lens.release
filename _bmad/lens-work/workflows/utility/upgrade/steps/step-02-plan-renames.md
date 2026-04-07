---
name: 'step-02-plan-renames'
description: 'Scan local branches, compute rename plan, identify YAML field changes, and plan initiative-state.yaml creation'
nextStepFile: './step-03-confirm-and-apply.md'
---

# Step 2: Migration Plan Computation

**Goal:** Compute the full migration plan: branch renames, lifecycle.yaml field changes, and initiative-state.yaml files to create.

---

## EXECUTION SEQUENCE

### 1. Scan Local Branches

```bash
git branch --format='%(refname:short)'
```

```yaml
branch_scan = invoke_command("git branch --format='%(refname:short)'").split('\n').map(b => b.trim()).filter(b => b != "")
```

### 2. Build Audience-To-Milestone Map

Audience-to-milestone token mapping (from migration descriptor `changes`):

```yaml
audience_map = {
  "small":  "techplan",
  "medium": "devproposal",
  "large":  "sprintplan",
  "base":   "dev-ready"
}

# v2 audience-root suffix patterns: {root}-{audience}
# v2 phase-branch suffix patterns:  {root}-{audience}-{phase}
audience_tokens = keys(audience_map)  # ["small", "medium", "large", "base"]
```

### 3. Classify Each Branch

```yaml
rename_plan = []
phase_branch_notes = []
initiative_roots = set()

for branch in branch_scan:
  # Split branch name into segments to detect audience token position
  segments = branch.split("-")

  # Find last occurrence of an audience token
  audience_idx = last_index_where(segments, s => audience_tokens.includes(s))

  if audience_idx == -1:
    continue  # No audience token — not a v2 migration candidate

  audience_token = segments[audience_idx]
  milestone_token = audience_map[audience_token]

  # Extract initiative root (everything before the audience token)
  init_root = segments.slice(0, audience_idx).join("-")
  initiative_roots.add(init_root)

  # Determine if this is a phase branch (has segments after the audience token)
  trailing_segments = segments.slice(audience_idx + 1)

  if trailing_segments.length == 0:
    # Pure audience-root branch: {root}-{audience} → {root}-{milestone}
    new_name = init_root + "-" + milestone_token
    rename_plan.push({ from: branch, to: new_name, type: "milestone-root" })
  else:
    # Phase branch: {root}-{audience}-{phase} — no v3 equivalent
    phase_branch_notes.push({
      branch: branch,
      note: "v2 phase branch — no v3 equivalent. Verify merged, then delete."
    })
```

### 4. Compute YAML Field Changes

Extract the lifecycle.yaml field transformations from the migration descriptor.
Auto-applicable types: `rename_key`, `rename_field`, `add_field`, `evolve_schema`, `change_default`.
Informational types: `add_capability`, `add_section`, `add_track`, `add_operation`, `add_query`.

```yaml
yaml_changes = []
informational_changes = []
auto_apply_types = ["rename_key", "rename_field", "add_field", "evolve_schema", "change_default"]

if migration != null:
  for change in migration.changes:
    if auto_apply_types.includes(change.type):
      yaml_changes.push({
        type: change.type,
        path: change.path,
        new_path: change.new_path || null,
        value: change.value || null,
        description: change.description || null,
        old_value: change.old_value || null
      })
    else:
      informational_changes.push({
        type: change.type,
        path: change.path,
        value: change.value || null,
        description: change.description || null
      })

  # Extract optional migrations for user display
  optional_migrations = migration.optional_migrations || []

output: |
  📋 YAML field changes from migration descriptor: ${yaml_changes.length} auto-apply, ${informational_changes.length} informational
  ${yaml_changes.map(c => `  ${c.type}: ${c.path}${c.new_path ? ' → ' + c.new_path : ''}`).join('\n')}
  ${informational_changes.length > 0 ? '\n  Informational (new capabilities available):\n' + informational_changes.map(c => `  ${c.type}: ${c.path} — ${c.description || c.value}`).join('\n') : ''}
  ${optional_migrations.length > 0 ? '\n  Optional migrations available: ' + optional_migrations.map(m => m.name).join(', ') : ''}
```

### 5. Plan Initiative-State YAML Creation

For each detected initiative root, check if `initiative-state.yaml` already exists. If not, plan its creation.

```yaml
init_state_plan = []

for root in initiative_roots:
  state_exists = git-orchestration.exec("git show ${root}:initiative-state.yaml 2>/dev/null").exit_code == 0

  if not state_exists:
    init_state_plan.push({
      initiative_root: root,
      branch: root,
      action: "create",
      content: {
        schema_version: 3,
        initiative: root,
        lifecycle_status: "active",
        current_phase: null,    # will be determined from branch topology
        last_updated: now_iso8601()
      }
    })
  else:
    # Exists — plan update to ensure schema_version: 3
    init_state_plan.push({
      initiative_root: root,
      branch: root,
      action: "update",
      fields: { schema_version: 3 }
    })
```

### 6. Summary

```yaml
output: |
  📋 Migration plan complete
  ├── Branch renames planned: ${rename_plan.length}
  ├── Phase branch advisories: ${phase_branch_notes.length}
  ├── YAML field changes: ${yaml_changes.length}
  └── Initiative-state files to create/update: ${init_state_plan.length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
