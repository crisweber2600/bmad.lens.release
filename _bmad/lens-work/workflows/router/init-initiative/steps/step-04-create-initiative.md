---
name: 'step-04-create-initiative'
description: 'Create the initiative config, scaffold local folders, and create the branch topology'
nextStepFile: './step-05-respond.md'
---

# Step 4: Create The Initiative

**Goal:** Materialize the initiative config, create any required local folders, and create the correct git topology for the selected scope.

---

## EXECUTION SEQUENCE

### 1. Create Config And Local Scaffold

```yaml
dirty_state = invoke: git-orchestration.check-dirty

if dirty_state.status == "dirty":
  output: |
    ❌ Working tree is not clean.
    ├── Files changed: ${dirty_state.files_changed || 0}
    └── Files: ${(dirty_state.files || []).join(', ')}

    Commit or stash the pending work, then rerun the initiative creation command.
  FAIL("❌ Initiative creation stopped to avoid mixing uncommitted work with new branch setup.")

target_projects_path = (profile != null and profile.target_projects_path != null and profile.target_projects_path != "") ? profile.target_projects_path : (module_config.target_projects_path || "TargetProjects")
commit_description = scope + " created"

initiative_config = {
  domain: domain,
  service: service,
  feature: feature,
  track: track,
  initiative_root: initiative_root,
  created: now_iso8601()
}

if scope == "domain":
  initiative_config.scope = "domain"
  initiative_config.initiative = domain

if scope == "service":
  initiative_config.scope = "service"
  initiative_config.initiative = service

if scope == "feature":
  initiative_config.scope = "feature"
  initiative_config.initiative = feature
  commit_description = "initiative created (track: " + track + ")"

write_yaml(config_path, initiative_config)

if scope == "domain":
  ensure_directory("${target_projects_path}/${domain}")

if scope == "service":
  ensure_directory("${target_projects_path}/${domain}/${service}")
```

### 2. Create Branch Topology, Commit, And Push

```yaml
invoke: git-orchestration.create-branch
params:
  branch_name: ${initiative_root}

invoke: git-orchestration.commit-artifacts
params:
  file_paths:
    - ${config_path}
  phase: INIT
  initiative: ${initiative_root}
  description: ${commit_description}

invoke: git-orchestration.push
params:
  branch: ${initiative_root}

if scope == "feature":
  invoke: git-orchestration.create-branch
  params:
    branch_name: "${initiative_root}-small"
    parent_branch: ${initiative_root}

  invoke: git-orchestration.push
  params:
    branch: "${initiative_root}-small"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`