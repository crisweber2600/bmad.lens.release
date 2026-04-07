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
# Dirty-state check moved to step-01-preflight for early fail.
# If execution reaches here, the working tree was clean at preflight time.

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

### 3. Register In Feature Index And Create Summary Stub On Main *(v3.3)*

When `features_registry.enabled` is true, atomically register the new feature in
`feature-index.yaml` on main and create a stub `summary.md`. This ensures the feature
is visible to all other features from the moment of creation.

```yaml
features_registry_config = load("lifecycle.yaml").features_registry
if features_registry_config.enabled:

  # 3a. Switch to main
  CURRENT_BRANCH = git symbolic-ref --short HEAD
  git checkout main
  git pull origin main

  # 3b. Register in feature-index.yaml
  invoke: git-orchestration.update-feature-index
  params:
    feature: ${initiative_root}
    domain: ${domain}
    service: ${service}
    status: draft
    owner: ${user_name}
    plan_branch: "${initiative_root}-plan"
    summary: "New initiative — ${commit_description}"
    relationships:
      depends_on: []
      blocks: []
      related: []
    updated_at: now_iso8601()

  # 3c. Create stub summary.md on main
  summary_path = resolve_summary_path(domain, service, initiative_root)
  mkdir -p $(dirname ${summary_path})
  write "${summary_path}":
    "# ${initiative_root} — Summary\n\n"
    "**Status:** draft\n"
    "**Goal:** ${commit_description}\n"
    "**Updated:** ${now_iso8601()}\n\n"
    "## Key Decisions\n\n_None yet_\n\n"
    "## Open Questions\n\n_None yet_\n\n"
    "## Dependencies\n\n- **Depends on:** none\n- **Blocks:** none\n"

  # 3d. Commit and push visibility update
  git add "${feature_index_path}" "${summary_path}"
  git commit -m "[VISIBILITY] ${initiative_root} — initiative created"
  git push origin main

  # 3e. Return to working branch
  git checkout ${CURRENT_BRANCH}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`