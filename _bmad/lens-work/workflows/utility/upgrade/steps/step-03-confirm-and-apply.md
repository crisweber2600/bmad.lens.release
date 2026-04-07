---
name: 'step-03-confirm-and-apply'
description: 'Render full migration plan, handle --dry-run or confirm, apply all changes (branch renames, YAML fields, initiative-state)'
nextStepFile: './step-04-write-version.md'
---

# Step 3: Confirm And Apply

**Goal:** Display the full migration plan (branch renames, YAML field changes, initiative-state.yaml creation). If `--dry-run`, display only and exit. Otherwise confirm with the user, apply all changes, and output remote push commands.

---

## EXECUTION SEQUENCE

### 1. Render The Full Plan

```yaml
total_changes = rename_plan.length + yaml_changes.length + init_state_plan.length

if total_changes == 0 and informational_changes.length == 0:
  output: "ℹ️  No v2 branches or fields detected. Only LENS_VERSION will be written."
else:
  output: |
    ## 📋 Upgrade Plan — v${detected_version || '2'} → v${target_version}

    ### Branch Renames (${rename_plan.length})

    ${rename_plan.length > 0 ?
      "| Current (v2) | New (v3) |\n|---|---|\n" +
      rename_plan.map(r => `| \`${r.from}\` | \`${r.to}\` |`).join('\n')
      : "No audience branches detected."}

    ${phase_branch_notes.length > 0 ? "### ⚠️  Phase Branch Advisories (not renamed)\n\n" +
      phase_branch_notes.map(n => `- \`${n.branch}\` — ${n.note}`).join('\n') : ""}

    ### YAML Field Changes — Auto-Apply (${yaml_changes.length})

    ${yaml_changes.length > 0 ?
      yaml_changes.map(c =>
        c.type == "rename_key" || c.type == "rename_field" ?
          `- ${c.type}: \`${c.path}\` → \`${c.new_path}\`` :
        c.type == "evolve_schema" ?
          `- ${c.type}: \`${c.path}\` — ${c.description}` :
        c.type == "change_default" ?
          `- ${c.type}: \`${c.path}\` from ${JSON.stringify(c.old_value)} → ${JSON.stringify(c.value)}` :
          `- ${c.type}: \`${c.path}\` = ${JSON.stringify(c.value)}`
      ).join('\n')
      : "No YAML field changes."}

    ${informational_changes.length > 0 ?
      "### New Capabilities Available (informational — no auto-apply)\n\n" +
      informational_changes.map(c => `- ${c.type}: \`${c.path}\` — ${c.description || c.value}`).join('\n')
      : ""}

    ### Initiative-State Files (${init_state_plan.length})

    ${init_state_plan.length > 0 ?
      init_state_plan.map(p => `- \`${p.initiative_root}\`: ${p.action} initiative-state.yaml on branch \`${p.branch}\``).join('\n')
      : "No initiative-state.yaml changes needed."}

    ### Version File

    - Write LENS_VERSION: ${target_version}.0.0

    ${optional_migrations && optional_migrations.length > 0 ?
      "### Optional Migrations\n\n" +
      "These can be run after the upgrade completes:\n\n" +
      optional_migrations.map(m =>
        `- **${m.name}**: ${m.description}\n` +
        (m.steps ? m.steps.map(s => `  - ${s}`).join('\n') : '')
      ).join('\n\n')
      : ""}

    **Current branch:** ${invoke_command("git branch --show-current")}

    > Phase branches have no v3 equivalent. Verify they are merged into their parent milestone branch before deleting.
    > Local renames will be applied immediately. Remote branches are NOT renamed automatically — commands will be provided.
```

### 2. Handle --dry-run

```yaml
if dry_run:
  output: |
    ════════════════════════════════════════
     DRY RUN COMPLETE — No changes applied
    ════════════════════════════════════════

    To execute this migration, run: /lens-upgrade
  STOP
```

### 3. Confirm

```yaml
if total_changes == 0:
  confirmed = true  # Nothing to confirm, just write version
else:
  user_input = ask_user("Apply ${total_changes} change(s) and write LENS_VERSION? [y/N]")
  confirmed = user_input.trim().toLowerCase() == "y" or user_input.trim().toLowerCase() == "yes"

if not confirmed:
  output: "❌ Upgrade cancelled. No changes made."
  STOP
```

### 4. Apply YAML Field Changes

Apply migration descriptor field changes to the control repo's `lifecycle.yaml`:

```yaml
if yaml_changes.length > 0:
  lifecycle_content = read_file("lens.core/_bmad/lens-work/lifecycle.yaml")
  yaml_doc = parse_yaml(lifecycle_content)

  for change in yaml_changes:
    if change.type == "rename_key":
      # Rename a top-level key: e.g., audiences → milestones
      old_value = yaml_doc[change.path]
      if old_value != undefined:
        yaml_doc[change.new_path] = old_value
        delete yaml_doc[change.path]

    elif change.type == "rename_field":
      # Rename a nested field path: e.g., milestones.small → milestones.techplan
      # Handle wildcard paths like phases.*.audience
      resolve_and_rename(yaml_doc, change.path, change.new_path)

    elif change.type == "add_field":
      # Add a new top-level field if it doesn't exist
      if yaml_doc[change.path] == undefined:
        yaml_doc[change.path] = change.value

    elif change.type == "evolve_schema":
      # Evolve an existing section with new schema fields
      # Preserves existing values, adds new fields from change.value
      existing = resolve_path(yaml_doc, change.path)
      if existing != undefined and change.value != null:
        for key, val in change.value:
          if existing[key] == undefined:
            existing[key] = val
        # Handle legacy_file → file migration if specified
        if change.value.legacy_file and change.value.file:
          if existing.file == change.value.legacy_file:
            existing.file = change.value.file
      elif existing == undefined and change.value != null:
        set_path(yaml_doc, change.path, change.value)

    elif change.type == "change_default":
      # Change a field's value only if it currently matches old_value
      current = resolve_path(yaml_doc, change.path)
      if current == change.old_value:
        set_path(yaml_doc, change.path, change.value)

  write_file("lens.core/_bmad/lens-work/lifecycle.yaml", serialize_yaml(yaml_doc))
  invoke_command("git add lens.core/_bmad/lens-work/lifecycle.yaml")
  invoke_command("git commit -m '[LENS:UPGRADE] apply lifecycle.yaml field migrations v${detected_version || 2} → v${target_version}'")
  output: "  ✅ Applied ${yaml_changes.length} YAML field changes to lifecycle.yaml"
```

### 5. Apply Local Branch Renames

```yaml
renames_applied = 0
current_branch = invoke_command("git branch --show-current").trim()
rename_errors = []

for rename in rename_plan:
  result = git-orchestration.exec("git branch -m ${rename.from} ${rename.to}")
  if result.exit_code == 0:
    renames_applied++
    output: "  ✅ Renamed: `${rename.from}` → `${rename.to}`"
  else:
    rename_errors.push({ rename: rename, error: result.stderr })
    output: "  ❌ Failed to rename `${rename.from}`: ${result.stderr}"
```

### 6. Create/Update Initiative-State YAML Files

```yaml
init_states_written = 0

for plan in init_state_plan:
  # Checkout the initiative root branch to write initiative-state.yaml
  invoke_command("git checkout ${plan.branch}")

  if plan.action == "create":
    content = serialize_yaml(plan.content)
    write_file("initiative-state.yaml", content)
    invoke_command("git add initiative-state.yaml")
    invoke_command("git commit -m '[LENS:UPGRADE] create initiative-state.yaml for ${plan.initiative_root}'")
    init_states_written++
    output: "  ✅ Created initiative-state.yaml on `${plan.branch}`"

  elif plan.action == "update":
    state = parse_yaml(read_file("initiative-state.yaml"))
    state.schema_version = plan.fields.schema_version
    state.last_updated = now_iso8601()
    write_file("initiative-state.yaml", serialize_yaml(state))
    invoke_command("git add initiative-state.yaml")
    invoke_command("git commit -m '[LENS:UPGRADE] update initiative-state.yaml schema_version for ${plan.initiative_root}'")
    init_states_written++
    output: "  ✅ Updated initiative-state.yaml on `${plan.branch}`"

# Return to original branch
invoke_command("git checkout ${current_branch}")
```

### 7. Output Remote Push Commands

```yaml
if renames_applied > 0:
  output: |
    ## Remote Sync Commands

    Run these commands to update remote branches (review before pushing):

    ```bash
    ${rename_plan
      .filter(r => !rename_errors.some(e => e.rename.from == r.from))
      .map(r => `git push origin ${r.to}:${r.to} && git push origin --delete ${r.from}`)
      .join('\n')}
    ```

output: |
  ✅ Branch renames applied: ${renames_applied}/${rename_plan.length}
  ✅ YAML field changes applied: ${yaml_changes.length}
  ✅ Initiative-state files written: ${init_states_written}/${init_state_plan.length}
  ${rename_errors.length > 0 ? "⚠️  Rename errors: " + rename_errors.length : ""}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
