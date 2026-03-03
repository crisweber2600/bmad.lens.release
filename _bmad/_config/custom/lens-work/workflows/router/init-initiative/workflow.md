---
name: init-initiative
description: User-facing initiative creation with two-file state architecture
agent: "@lens"
trigger: "/new-domain, /new-service, /new-feature (canonical); #new-* accepted"
category: router
---

# Init Initiative Router

**Purpose:** Accept user input, resolve target repos, delegate git ops to git-orchestration skill, and write the two-file state architecture for a new initiative.

---

## Input Parameters

```yaml
initiative_name: string    # User-provided name (e.g., "Rate Limiting Feature")
layer: enum                # domain | service | microservice | feature
domain: string | null      # Domain context (required for service/microservice layers)
service: string | null      # Service context (required for microservice layer)
```

---

<critical>
ANTI-HALLUCINATION GATE: If the user provided input alongside the command invocation
(e.g., "/new-domain BMAD" or "/new-service Auth" or "/new-feature Rate Limiting"),
that input IS the initiative/domain/service/feature name. Do NOT invent, substitute,
or ignore user-provided values. Every field below that uses `ask:` MUST capture the
user's ACTUAL response — never fabricate values.

Command-arg parsing:
```yaml
user_args = parse_command_args()
if user_args:
  initiative_name = user_args     # User already provided the name
  # For /new-domain: domain = user_args
  # For /new-service: service = user_args
  # For /new-feature: initiative_name = user_args
else:
  # Ask the user — but NEVER invent a value
  ask: initiative_name
```
</critical>

---

## Execution Sequence

### 0. Verify Git State (Pre-flight Check)

```bash
# Ensure we're in BMAD control repo
if [ ! -d ".git" ] || [ ! -d "_bmad" ]; then
  error "Must run from BMAD control repo root"
  exit 1
fi

# Ensure clean working directory
if ! git diff-index --quiet HEAD --; then
  error "Uncommitted changes detected. Please commit or stash before creating initiative."
  exit 1
fi

# Sync with remote
git fetch origin main
```

### 0-pre. Batch Context Pre-Load (Parallel)

```yaml
# OPTIMIZATION: Load all context files in a single parallel batch BEFORE
# the conditional Steps 0a/0b/0c. Each step then uses already-loaded data
# instead of making separate sequential file-read tool calls.

parallel:
  - load_profile:
      path: "_bmad-output/lens-work/personal/profile.yaml"
      store: profile_raw           # Used by Step 0c — no separate load needed

  - scan_domain_files:
      glob: "_bmad-output/lens-work/initiatives/*/Domain.yaml"
      store: domain_yaml_files     # Used by Step 0a (service-layer)

  - scan_service_files:
      glob: "_bmad-output/lens-work/initiatives/*/*/Service.yaml"
      store: service_yaml_files    # Used by Step 0b (feature-layer)

  - load_state:
      path: "_bmad-output/lens-work/state.yaml"
      store: state                 # Used by Steps 0a/0b for active_initiative check

# All four results are now available in memory for Steps 0a, 0b, and 0c.
# Steps proceed with cached values — no additional file reads are needed.
```

---

### 0a. Load Parent Domain Context (Service-Layer)

${if layer == "service"}
```yaml
# Service-layer MUST have a parent domain initiative.
# Strategy: try active_initiative first, then auto-discover, only error if zero domains exist.
# NOTE: state and domain_yaml_files are already loaded from Step 0-pre (Batch Context Pre-Load).
# No additional file reads needed here.

domain_config = null

# Attempt 1: Use active_initiative if set and points to a Domain.yaml
if state.active_initiative != null:
  domain_config_path = "bmad.lens.release/_bmad-output/lens-work/initiatives/${state.active_initiative}/Domain.yaml"
  if exists(domain_config_path):
    candidate = load(domain_config_path)
    if candidate.layer == "domain":
      domain_config = candidate

# Attempt 2: Auto-discover domains using pre-loaded domain_yaml_files scan
if domain_config == null:
  # domain_yaml_files already populated by Step 0-pre parallel scan
  if domain_yaml_files.length == 0:
    error: "No domain found. Create a domain first with /new-domain."
    exit: 1
  elif domain_yaml_files.length == 1:
    domain_config = load(domain_yaml_files[0])
    # Auto-heal: set active_initiative so future commands skip scanning
    state.active_initiative = domain_config.domain_prefix
    save("bmad.lens.release/_bmad-output/lens-work/state.yaml", state)
    info: "Auto-selected domain '${domain_config.domain}' (${domain_config.domain_prefix}) — state.yaml updated."
  else:
    # Multiple domains — let user pick
    prompt: |
      Multiple domains found. Select parent domain:
      ${for file in domain_yaml_files}
      [${index}] ${load(file).domain} (${load(file).domain_prefix})
      ${endfor}
    domain_config = load(selected_file)
    # Update state to selected domain
    state.active_initiative = domain_config.domain_prefix
    save("bmad.lens.release/_bmad-output/lens-work/state.yaml", state)

if domain_config.layer != "domain":
  error: "Active initiative is not a domain. Switch to a domain first or create one with /new-domain."
  exit: 1

# Inherit from parent domain
domain = domain_config.domain
domain_prefix = domain_config.domain_prefix
parent_target_repos = domain_config.target_repos
question_mode = domain_config.question_mode
```
${endif}

### 0b. Load Parent Context (Feature-Layer)

${if layer == "feature"}
```yaml
# Feature-layer: needs a parent context (service OR domain).
# Strategy: check active_initiative, then auto-discover, only error if zero parents exist.
# NOTE: state, domain_yaml_files, and service_yaml_files are already loaded from Step 0-pre.
# No additional file reads are needed for the initial discovery.

parent_config = null
parent_layer = null

# Attempt 1: Use active_initiative if set and points to a Service.yaml or Domain.yaml
if state.active_initiative != null:
  # Check for Service.yaml first (more specific parent)
  service_config_path = "bmad.lens.release/_bmad-output/lens-work/initiatives/${state.active_initiative}/Service.yaml"
  if exists(service_config_path):
    candidate = load(service_config_path)
    if candidate.layer == "service":
      parent_config = candidate
      parent_layer = "service"

  # Fall back to Domain.yaml
  if parent_config == null:
    domain_config_path = "bmad.lens.release/_bmad-output/lens-work/initiatives/${state.active_initiative}/Domain.yaml"
    if exists(domain_config_path):
      candidate = load(domain_config_path)
      if candidate.layer == "domain":
        parent_config = candidate
        parent_layer = "domain"

# Attempt 2: Auto-discover using pre-loaded service_yaml_files and domain_yaml_files from Step 0-pre
if parent_config == null:
  # service_yaml_files and domain_yaml_files already populated by Step 0-pre parallel scan

  all_parents = []
  for file in service_yaml_files:
    all_parents.append({file: file, config: load(file), type: "service"})
  for file in domain_yaml_files:
    all_parents.append({file: file, config: load(file), type: "domain"})

  if all_parents.length == 0:
    error: "No parent found. Create a domain (/new-domain) or service (/new-service) first."
    exit: 1
  elif all_parents.length == 1:
    parent_config = all_parents[0].config
    parent_layer = all_parents[0].type
    # Auto-heal state
    if parent_layer == "service":
      state.active_initiative = "${parent_config.domain_prefix}/${parent_config.service_prefix}"
    else:
      state.active_initiative = parent_config.domain_prefix
    save("bmad.lens.release/_bmad-output/lens-work/state.yaml", state)
    info: "Auto-selected ${parent_layer} '${parent_config[parent_layer == 'service' ? 'service' : 'domain']}' — state.yaml updated."
  else:
    # Multiple parents — let user pick
    prompt: |
      Select parent for this feature:
      ${for parent in all_parents}
      [${index}] [${parent.type}] ${parent.config.domain}${parent.type == "service" ? "/" + parent.config.service : ""} (${parent.type == "service" ? parent.config.domain_prefix + "/" + parent.config.service_prefix : parent.config.domain_prefix})
      ${endfor}
    selected = all_parents[selection]
    parent_config = selected.config
    parent_layer = selected.type
    # Update state
    if parent_layer == "service":
      state.active_initiative = "${parent_config.domain_prefix}/${parent_config.service_prefix}"
    else:
      state.active_initiative = parent_config.domain_prefix
    save("bmad.lens.release/_bmad-output/lens-work/state.yaml", state)

# Inherit from parent
domain = parent_config.domain
domain_prefix = parent_config.domain_prefix
parent_target_repos = parent_config.target_repos
question_mode = parent_config.question_mode

if parent_layer == "service":
  service = parent_config.service
  service_prefix = parent_config.service_prefix
else:
  service = null
  service_prefix = null
```
${endif}

### 0c. Load User Profile Preferences  # REQ-2, REQ-3

```yaml
# Use pre-loaded profile data from Step 0-pre (no additional file read needed).
# profile_raw was already loaded in the parallel batch; extract preferences here.

if profile_raw != null:
  profile = profile_raw
  profile_question_mode = profile.preferences.question_mode || "interactive"   # REQ-2
  profile_tracker       = profile.preferences.tracker       || "none"          # REQ-3
else:
  profile_question_mode = "interactive"   # REQ-2 default
  profile_tracker       = "none"          # REQ-3 default

# For domain / microservice layers, profile values become the defaults
# (override happens in Step 1a). For service / feature layers, parent
# inheritance from Steps 0a/0b takes precedence.
if layer != "service" && layer != "feature":
  question_mode = profile_question_mode   # REQ-2

# Store tracker value for downstream use (S2.3 Jira ticket prompt)  # REQ-3
tracker = profile_tracker
```

### 1. Gather Initiative Details

${if layer == "service"}
```
🧭 New Service Initiative

Parent domain: ${domain} (${domain_prefix})

**Service name:** ${service_from_argument || "(provide service name)"}

# The service name is typically provided as the command argument:
# /new-service Lens → service = "Lens"
# If not provided, ask:
${if !service_from_argument}
**Service:** (service name, e.g., "Auth Service", "Payment Gateway")
${endif}

**Target repos:** Inherited from domain (${parent_target_repos})
Keep all? [Y/n] (or select subset)
```
${elif layer == "feature"}
```
🧭 New Feature Initiative

${if parent_layer == "service"}
Parent service: ${service} (${domain_prefix}/${service_prefix})
${else}
Parent domain: ${domain} (${domain_prefix})
${endif}

**Feature:** ${feature_from_argument || "(provide feature name)"}

# Feature name is typically the command argument:
# /new-feature Rate Limiting → feature = "Rate Limiting"
${if !feature_from_argument}
**Feature name:** (e.g., "Rate Limiting", "OAuth Integration")
${endif}

**Target repos:** Inherited from parent (${parent_target_repos})
${if parent_target_repos.length > 1}
Select repos or keep all? [A] All (default)
${endif}
```
${else}
```
🧭 New Initiative Setup

Please provide the following details:

**Name:** (descriptive name for this initiative)
**Layer:** [1] Domain  [2] Service  [3] Microservice  [4] Feature

${if layer == "microservice"}
**Domain:** (parent domain for this ${layer})
**Service:** (parent service for this microservice)
${endif}
```
${endif}

### 1a. Choose Question Mode  # REQ-2

${if layer != "service" && layer != "feature"}
```
How would you like to answer phase questions?

**[1] Interactive (chat)** — Current guided flow
**[2] Batch MD** — Single file per phase, filled in one shot

Default from profile: ${question_mode}   (press Enter to keep)
Select mode: [1] or [2] (default: ${question_mode == "batch" ? "2" : "1"})
```

```yaml
# question_mode was pre-loaded from profile in Step 0c (REQ-2)
# User may override; if they press Enter the profile default is kept.
if selection != "":
  question_mode = selection == "2" ? "batch" : "interactive"
# else: question_mode retains the profile-sourced default from Step 0c
```
${else}
```yaml
# Service/Feature-layer: inherit question_mode from parent
# Already loaded in Step 0a (service) or Step 0b (feature)
```
${endif}

### 1b. Choose Initiative Track (v2 — Lifecycle Contract)

${if layer == "feature" || layer == "microservice"}
```
Which lifecycle track for this initiative?

**[1] Full**         — Complete lifecycle: preplan → businessplan → techplan → devproposal → sprintplan
**[2] Feature**      — Known business context: businessplan → techplan → devproposal → sprintplan
**[3] Tech-Change**  — Pure technical: techplan → sprintplan
**[4] Hotfix**       — Urgent fix: techplan only (fast to execution)
**[5] Spike**        — Research only: preplan (no implementation)
**[6] QuickDev**     — Rapid execution: techplan → devproposal (small → medium, parity verification)

Default: full   (press Enter to keep)
Select track: [1-6] (default: 1)
```

```yaml
# Load lifecycle.yaml to derive track-specific phases and audiences
lifecycle = load("_bmad/_config/custom/lens-work/lifecycle.yaml")

track_map = {1: "full", 2: "feature", 3: "tech-change", 4: "hotfix", 5: "spike", 6: "quickdev"}
track = track_map[selection] || "full"

# Derive active phases and audiences from lifecycle contract
active_phases = lifecycle.tracks[track].phases
track_audiences = lifecycle.tracks[track].audiences
start_phase = lifecycle.tracks[track].start_phase
```
${else}
```yaml
# Domain/Service layers don't use tracks (organizational containers only)
track = null
active_phases = []
track_audiences = []
```
${endif}

### 1.5 Confirmation Gate

```yaml
# ANTI-HALLUCINATION: Echo back ALL captured values for user confirmation
# before ANY branch creation or state mutation.

${if layer == "domain"}
output: |
  📋 Confirm initiative details:
  
  Type: Domain
  Domain name: ${domain || initiative_name}
  Question mode: ${question_mode}
  
  Proceed? [Y/n/edit]
${elif layer == "service"}
output: |
  📋 Confirm initiative details:
  
  Type: Service
  Parent domain: ${domain} (${domain_prefix})
  Service name: ${service}
  Target repos: ${target_repos}
  
  Proceed? [Y/n/edit]
${elif layer == "feature"}
output: |
  📋 Confirm initiative details:

  Type: Feature
  Parent: ${parent_layer == "service" ? service + " (" + domain + ")" : domain}
  Feature name: ${initiative_name}
  Track: ${track} (${active_phases.join(" → ")})
  Audiences: ${track_audiences.join(" → ")}
  Target repos: ${target_repos}

  Proceed? [Y/n/edit]
${else}
output: |
  📋 Confirm initiative details:
  
  Name: ${initiative_name}
  Layer: ${layer}
  Question mode: ${question_mode}
  
  Proceed? [Y/n/edit]
${endif}

if response == "n":
  exit: "Initiative creation cancelled by user."
elif response == "edit":
  # Return to Step 1 to re-gather details
  goto: step_1
```

### 2. Generate Initiative ID

```bash
# REQ-1, REQ-3: Work-item tracker prompt for feature-layer when tracker != "none"
tracker_id=""
if [ "${layer}" == "feature" ] && [ "${tracker}" != "none" ]; then
  # REQ-3: Prompt for work-item ID from the configured tracker
  if [ "${tracker}" == "jira" ]; then
    ask: "Jira ticket ID (e.g., BMAD-123):"
  elif [ "${tracker}" == "azure-devops" ]; then
    ask: "Azure DevOps work item ID (e.g., 12345):"
  else
    ask: "Work item ID from your tracker:"
  fi
  if [ -n "${answer}" ]; then
    tracker_id="${answer}"  # REQ-3: Store raw work-item ID
  fi
fi

if [ "${layer}" == "domain" ]; then
  # Domain-layer: use domain_prefix as the initiative ID (no random suffix).
  # The domain name IS the identity — no separate initiative config file needed.
  initiative_id="${domain_prefix}"
elif [ "${layer}" == "service" ]; then
  # Service-layer: use {domain_prefix}/{service_prefix} as initiative ID (no random suffix).
  # The service name IS the identity — Service.yaml replaces separate initiative config.
  service_prefix=$(echo "${service}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
  initiative_id="${domain_prefix}/${service_prefix}"  # initiative_id uses / for file paths; branch name uses -
  initiative_name="${initiative_name:-${service}}"
elif [ "${layer}" == "feature" ]; then
  # REQ-1: Feature ID = sanitized name only (no random suffix)
  sanitized_name=$(echo "${initiative_name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
  # REQ-1, REQ-3: Prepend work-item ID if provided (from any tracker)
  if [ -n "${tracker_id}" ]; then
    sanitized_tracker_id=$(echo "${tracker_id}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
    initiative_id="${sanitized_tracker_id}-${sanitized_name}"  # e.g., bmad-123-onboarding-enhancements or 12345-onboarding-enhancements
  else
    initiative_id="${sanitized_name}"
  fi
else
  # Microservice layers: generate random suffix
  # Format: {sanitized_name}-{random_6char}
  # Example: rate-limit-x7k2m9
  initiative_id=$(echo "${initiative_name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-20)-$(openssl rand -hex 3)
fi
```

### 2a. Duplicate Initiative Detection

```yaml
# REQ-1: Duplicate initiative detection
# Check if an initiative with this ID already exists before creating anything.
# Applies to ALL layers (domain, service, feature, microservice).

initiatives_root = "bmad.lens.release/_bmad-output/lens-work/initiatives"

if layer == "domain":
  # REQ-1: Domain — check nested path: initiatives/{domain_prefix}/Domain.yaml
  initiative_path = "${initiatives_root}/${domain_prefix}/Domain.yaml"
elif layer == "service":
  # REQ-1: Service — check nested path: initiatives/{domain_prefix}/{service_prefix}/Service.yaml
  initiative_path = "${initiatives_root}/${domain_prefix}/${service_prefix}/Service.yaml"
elif layer == "feature":
  # REQ-1: Feature — check flat path: initiatives/{initiative_id}.yaml
  initiative_path = "${initiatives_root}/${initiative_id}.yaml"
else:
  # REQ-1: Microservice/other — check flat path: initiatives/{initiative_id}.yaml
  initiative_path = "${initiatives_root}/${initiative_id}.yaml"

if file_exists(initiative_path):
  error: |
    ❌ Initiative already exists: ${initiative_id}
    ├── Config: ${initiative_path}
    └── Choose a different name or archive the existing initiative

  ask: "Enter a different name (or 'cancel' to abort):"
  if answer == "cancel":
    exit: 0
  else:
    # Re-sanitize the new name and re-check
    name = answer
    if layer == "domain":
      domain = name
      domain_prefix = normalize_domain_prefix(name)
      initiative_id = domain_prefix
      initiative_path = "${initiatives_root}/${domain_prefix}/Domain.yaml"
    elif layer == "service":
      service = name
      service_prefix = $(echo "${name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
      initiative_id = "${domain_prefix}/${service_prefix}"
      initiative_path = "${initiatives_root}/${domain_prefix}/${service_prefix}/Service.yaml"
    elif layer == "feature":
      initiative_name = name
      initiative_id = $(echo "${name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
      initiative_path = "${initiatives_root}/${initiative_id}.yaml"
    else:
      initiative_name = name
      initiative_id = $(echo "${name}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-20)-$(openssl rand -hex 3)
      initiative_path = "${initiatives_root}/${initiative_id}.yaml"

    if file_exists(initiative_path):
      error: "Still a duplicate: ${initiative_id}. Please archive the existing initiative first."
      exit: 1
```

### 3. Resolve Target Repos

```yaml
service_map = load("bmad.lens.release/_bmad/lens-work/service-map.yaml")

# Resolve based on layer
if layer == "domain":
  # Let user select multiple repos from service map
  prompt: |
    Select target repos for this domain initiative:
    ${for repo in service_map.repos}
    [${index}] ${repo.name}
    ${endfor}
    [A] All repos
  target_repos = selected_repos

elif layer == "service" || layer == "microservice":
  # Service-layer: inherit target_repos from parent Domain.yaml
  # User can keep all or select subset
  target_repos = parent_target_repos  # Already loaded in Step 0a

elif layer == "feature":
  # Feature-layer: inherit target_repos from parent (service or domain)
  # User can keep all or select subset
  if parent_target_repos.length == 1:
    target_repos = parent_target_repos  # Single repo — auto-inherit
  else:
    prompt: |
      Select target repos for this feature (inherited from parent):
      ${for repo in parent_target_repos}
      [${index}] ${repo}
      ${endfor}
      [A] All repos (default)
    target_repos = selected_repos || parent_target_repos
```

### 4. Resolve Domain Prefix

```yaml
# Domain prefix for branch naming
# Used as first segment of branch names: {domain_prefix}-{service_prefix}-{initiative_id}-{audience}-{phase_name}-{workflow}
normalize_domain_prefix(input):
  token = input or ""
  if token contains "/":
    token = token.split("/").last_non_empty()
  token = token.to_lower()
  token = token.replace(/[^a-z0-9-]/g, "-")
  token = token.replace(/-+/g, "-").trim("-")
  return token

selected_repo = find(service_map.repos, repo => repo.name == target_repos[0])

if layer == "domain" || layer == "microservice":
  # Domain/microservice flows must resolve from explicit domain input.
  domain_prefix = normalize_domain_prefix(domain)
elif layer == "service":
  # Service-layer: domain_prefix already inherited from Domain.yaml in Step 0a.
  # No resolution needed — skip.
  pass
elif layer == "feature":
  # Feature-layer: domain_prefix already inherited from parent in Step 0b.
  # No resolution needed — skip.
  pass

if domain_prefix == "":
  error: "Unable to resolve domain prefix for ${initiative_name}. Provide domain or add repo domain metadata to service-map.yaml."
  exit: 1
```

### 4a. Resolve Docs Path (Docs/{Domain}/{Service}/{Repo}/{Feature})

```yaml
normalize_docs_segment(input):
  token = input or ""
  token = token.trim()
  token = token.replace(/[\\/:*?"<>|]/g, "-")
  token = token.replace(/\s+/g, "-")
  token = token.replace(/-+/g, "-").trim("-")
  return token

docs_domain = normalize_docs_segment(domain)
if docs_domain == "":
  docs_domain = normalize_docs_segment(domain_prefix)
if docs_domain == "":
  docs_domain = normalize_docs_segment(selected_repo.domain)

docs_service = normalize_docs_segment(service)
if docs_service == "":
  docs_service = normalize_docs_segment(selected_repo.service)

docs_repo = normalize_docs_segment(selected_repo.name)
docs_feature = normalize_docs_segment(initiative_id)

if layer == "domain":
  docs_service = ""
  docs_repo = ""

if layer == "service":
  docs_repo = ""
  docs_feature = ""

# REQ-11: Type-discriminator directories for self-describing path hierarchy
segments = [docs_domain, docs_service]
if docs_repo != "":
  segments.push("repo")
  segments.push(docs_repo)
if docs_feature != "":
  segments.push("feature")
  segments.push(docs_feature)
docs_segments = segments.filter(seg => seg != "")
docs_path = "docs/" + docs_segments.join("/")

# REQ-10: Compute BmadDocs path for co-located per-initiative output
bmad_docs = docs_path + "/BmadDocs"   # REQ-10
```

### 4b. Resolve Service Prefix (Service-Layer)

```yaml
${if layer == "service"}
normalize_service_prefix(input):
  token = input or ""
  if token contains "/":
    token = token.split("/").last_non_empty()
  token = token.to_lower()
  token = token.replace(/[^a-z0-9-]/g, "-")
  token = token.replace(/-+/g, "-").trim("-")
  return token

service_prefix = normalize_service_prefix(service)
${endif}
```

### 4c. Compute Initiative Root (Feature-Layer)

```yaml
${if layer == "feature" || layer == "microservice"}
# Build {initiative_root} from parent context + initiative_id
# The root branch is the initiative's home — the "base" audience level.

if service_prefix != null && service_prefix != "":
  if target_repos.length > 1:
    # Multi-repo: include repo name for disambiguation
    repo_name = normalize_domain_prefix(target_repos[0])
    initiative_root = "${domain_prefix}-${service_prefix}-${repo_name}-${initiative_id}"
  else:
    initiative_root = "${domain_prefix}-${service_prefix}-${initiative_id}"
else:
  # Domain-parent (repo-level feature, no service)
  initiative_root = "${domain_prefix}-${initiative_id}"

# Branch root computed
${endif}
```

### 5. Delegate Branch Creation to Git-Orchestration

```yaml
# Hand off to git-orchestration skill for git operations
invoke: git-orchestration.init-initiative
params:
  initiative_id: ${initiative_id}
  initiative_name: "${initiative_name}"
  layer: ${layer}
  domain_prefix: ${domain_prefix}
  target_repos: ${target_repos}

${if layer == "domain"}
# Domain-layer: git-orchestration creates ONLY the domain branch (pushed immediately to remote):
# - ${domain_prefix}
#
# Domain branches are organizational — no audience/phase branches needed.
# Service/feature initiatives within this domain will create their own topology.
# PUSH: git push -u origin ${domain_prefix}
${elif layer == "service"}
# Service-layer: git-orchestration creates ONLY the service branch (pushed immediately to remote):
# - ${domain_prefix}-${service_prefix}  (hyphen-separated, e.g., bmaddomain-lens)
#
# Service branches are organizational — no audience/phase branches needed.
# Feature initiatives within this service will create their own topology.
# PUSH: git push -u origin ${domain_prefix}-${service_prefix}
${else}
# Feature-layer (v2 — track-aware branch creation):
#
# initiative_root = ${initiative_root} (computed in Step 4c)
#
# git-orchestration creates branches based on track (ALL pushed immediately to remote):
# - ${initiative_root}                    (initiative root / base)
# - ${initiative_root}-small              (always created)
# - ${initiative_root}-medium             (if track has medium audience)
# - ${initiative_root}-large              (if track has large audience)
#
# Track-specific audience creation:
#   full/feature:   small + medium + large  (3 audience branches)
#   tech-change:    small + medium + large  (3 audience branches, medium/large constitution-controlled)
#   hotfix:         small only              (1 audience branch, promotes directly to base)
#   spike:          small only              (1 audience branch, no promotion)
#
# NOTE: No phase branches created at init. Phase branches are created by
# phase router workflows (e.g., /preplan creates ${initiative_root}-small-preplan).
${endif}
```

### 6. Write Initiative Config (Git-Committed)

${if layer == "domain"}
**Domain-layer: SKIP this step.** Domain.yaml (created in Step 6a) serves as
both the domain descriptor AND the initiative config. No separate
`{initiative_id}.yaml` file is created for domain-layer.
${elif layer == "service"}
**Service-layer: SKIP this step.** Service.yaml (created in Step 6a) serves as
both the service descriptor AND the initiative config. No separate
`{initiative_id}.yaml` file is created for service-layer.
${else}
Create directory and file at `bmad.lens.release/_bmad-output/lens-work/initiatives/${initiative_id}.yaml`:

```yaml
# v2 — Lifecycle Contract initiative config
lifecycle_version: 2

id: ${initiative_id}
name: "${initiative_name}"
layer: ${layer}
domain: ${domain}
domain_prefix: ${domain_prefix}
service: ${service}
service_prefix: ${service_prefix}
question_mode: ${question_mode}
tracker_id: ${tracker_id || ""}            # REQ-1, REQ-3: Work-item ID (feature-layer, any tracker)
created_at: "${ISO_TIMESTAMP}"
created_by: ${profile.name}  # From profile.yaml (loaded in Step 0c)
target_repos:
${for repo in target_repos}
  - ${repo}
${endfor}
docs:
  root: "docs"
  domain: "${docs_domain}"
  service: "${docs_service}"
  repo: "${docs_repo}"
  feature: "${docs_feature}"
  path: "${docs_path}"
  bmad_docs: "${bmad_docs}"   # REQ-10: BmadDocs co-located output path

# v2: Track & Phases (from lifecycle.yaml)
track: ${track}                            # full|feature|tech-change|hotfix|spike
active_phases:                             # Derived from track via lifecycle.yaml
${for phase in active_phases}
  - ${phase}
${endfor}
audiences:                                 # Derived from track via lifecycle.yaml
${for aud in track_audiences}
  - ${aud}
${endfor}

# v2: Named phase status
phase_status:
${for phase in ["preplan", "businessplan", "techplan", "devproposal", "sprintplan"]}
  ${phase}: null
${endfor}
current_phase: null                        # Set when first phase starts

# v2: Initiative root (replaces featureBranchRoot)
initiative_root: "${initiative_root}"

# Governance
constitution_mode: advisory                # advisory|enforced
scope: ${target_repos.length > 1 ? "service" : "repo"}
coupling: none

# Lifecycle v2 fields populated above:
# - lifecycle_version: 2
# - track: ${track}
# - active_phases: [...] (derived from track)
# - phase_status: {...} (named phases)
```

> **Note:** This file is committed to the repo and shared across collaborators. It holds the canonical initiative definition with the v2 lifecycle contract fields: **track** (determines which phases are active), **active_phases** (derived from track), and **initiative_root** (branch name root). The `initiative_root` is computed from parent context: `{domain_prefix}-{service_prefix}-{initiative_id}` (service parent) or `{domain_prefix}-{initiative_id}` (domain parent). Phase branches (e.g., `-small-preplan`) are created by phase router workflows, NOT at init.
${endif}

### 6a. Scaffold Domain/Service Folders (Domain/Service-Layer)

${if layer == "domain"}

Create domain folder structure with `.gitkeep` files and a `Domain.yaml` descriptor:

```bash
# Scaffold domain folders
DOMAIN_NAME="${domain_prefix}"

# Create domain folders with .gitkeep
mkdir -p "_bmad-output/lens-work/initiatives/${DOMAIN_NAME}"
touch "_bmad-output/lens-work/initiatives/${DOMAIN_NAME}/.gitkeep"

mkdir -p "TargetProjects/${DOMAIN_NAME}"
touch "TargetProjects/${DOMAIN_NAME}/.gitkeep"

mkdir -p "Docs/${DOMAIN_NAME}"
touch "Docs/${DOMAIN_NAME}/.gitkeep"
```

Create `bmad.lens.release/_bmad-output/lens-work/initiatives/${DOMAIN_NAME}/Domain.yaml`.
This file serves as BOTH the domain descriptor AND the initiative config for domain-layer.
No separate `{initiative_id}.yaml` is created.

```yaml
# Domain.yaml — single source of truth for domain-layer initiatives
domain: "${domain}"
domain_prefix: "${domain_prefix}"
layer: domain
question_mode: ${question_mode}
created_at: "${ISO_TIMESTAMP}"
created_by: "${profile.name}"  # From profile.yaml (loaded in Step 0c)
target_repos:
${for repo in target_repos}
  - ${repo}
${endfor}
folders:
  initiatives: "_bmad-output/lens-work/initiatives/${domain_prefix}/"
  target_projects: "TargetProjects/${domain_prefix}/"
  docs: "Docs/${domain_prefix}/"
docs:
  root: "docs"
  domain: "${docs_domain}"
  service: ""
  repo: ""
  feature: ""
  path: "${docs_path}"
branch: "${domain_prefix}"
gates:
  - name: tests-pass
    status: open
blocks: []
```

> **Note:** Domain.yaml is both the domain anchor and the initiative config for domain-layer.
> It contains target_repos, docs, gates, and blocks — the same fields other layers
> store in `{initiative_id}.yaml`. Service and feature initiatives within this domain
> will be created as separate files in the initiatives folder.
> The `.gitkeep` files ensure empty directories are committed.

${elif layer == "service"}

Create service folder structure under the parent domain with `.gitkeep` files and a `Service.yaml` descriptor:

```bash
# Scaffold service folders under domain
DOMAIN_NAME="${domain_prefix}"
SERVICE_NAME="${service_prefix}"

# Create service folders with .gitkeep (nested under domain)
mkdir -p "_bmad-output/lens-work/initiatives/${DOMAIN_NAME}/${SERVICE_NAME}"
touch "_bmad-output/lens-work/initiatives/${DOMAIN_NAME}/${SERVICE_NAME}/.gitkeep"

mkdir -p "TargetProjects/${DOMAIN_NAME}/${SERVICE_NAME}"
touch "TargetProjects/${DOMAIN_NAME}/${SERVICE_NAME}/.gitkeep"

mkdir -p "Docs/${DOMAIN_NAME}/${SERVICE_NAME}"
touch "Docs/${DOMAIN_NAME}/${SERVICE_NAME}/.gitkeep"
```

Create `bmad.lens.release/_bmad-output/lens-work/initiatives/${DOMAIN_NAME}/${SERVICE_NAME}/Service.yaml`.
This file serves as BOTH the service descriptor AND the initiative config for service-layer.
No separate `{initiative_id}.yaml` is created.

```yaml
# Service.yaml — single source of truth for service-layer initiatives
domain: "${domain}"
domain_prefix: "${domain_prefix}"
service: "${service}"
service_prefix: "${service_prefix}"
layer: service
question_mode: ${question_mode}
created_at: "${ISO_TIMESTAMP}"
created_by: "${profile.name}"  # From profile.yaml (loaded in Step 0c)
target_repos:
${for repo in target_repos}
  - ${repo}
${endfor}
folders:
  initiatives: "_bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/"
  target_projects: "TargetProjects/${domain_prefix}/${service_prefix}/"
  docs: "Docs/${domain_prefix}/${service_prefix}/"
docs:
  root: "docs"
  domain: "${docs_domain}"
  service: "${docs_service}"
  repo: ""
  feature: ""
  path: "${docs_path}"
branch: "${domain_prefix}-${service_prefix}"
gates:
  - name: tests-pass
    status: open
blocks: []
```

> **Note:** Service.yaml is both the service anchor and the initiative config for service-layer.
> It contains target_repos, docs, gates, and blocks — the same fields other layers
> store in `{initiative_id}.yaml`. Feature initiatives within this service
> will be created as separate files in the initiatives folder.
> The `.gitkeep` files ensure empty directories are committed.

${endif}

### 6b. Create BmadDocs Directory & Copy Initiative Config  # REQ-10

${if layer != "domain" && layer != "service"}
```bash
# REQ-10: Create BmadDocs directory for co-located per-initiative output
mkdir -p "${bmad_docs}"

# REQ-10: Copy canonical initiative config to BmadDocs for co-location
cp "_bmad-output/lens-work/initiatives/${initiative_id}.yaml" "${bmad_docs}/initiative.yaml"
```

> **Note:** BmadDocs co-locates per-initiative output (dev stories, sprint backlog,
> initiative config copy) with the initiative's planning docs. The canonical
> initiative config remains at `_bmad-output/lens-work/initiatives/` for backward
> compatibility; the BmadDocs copy is a convenience snapshot.
${endif}

### 7. Write Personal State (Git-Ignored)

Write to `bmad.lens.release/_bmad-output/lens-work/state.yaml`:

```yaml
# v2 — Lifecycle Contract personal state
lifecycle_version: 2
lens_contract_version: "2.0"

active_initiative: ${initiative_id}
${if layer == "domain"}
# For domain-layer: active_initiative = domain_prefix (e.g., "bmad")
# Load via: initiatives/${active_initiative}/Domain.yaml
${elif layer == "service"}
# For service-layer: active_initiative = {domain_prefix}/{service_prefix} (e.g., "bmaddomain/lens")
# Load via: initiatives/${active_initiative}/Service.yaml
${else}
# For feature/microservice: active_initiative = generated ID (e.g., "rate-limit-x7k2m9")
# Load via: initiatives/${active_initiative}.yaml
${endif}

# v2: Named phase tracking
current_phase: ${layer != "domain" && layer != "service" ? "null  # Set when first phase starts" : "null"}
active_track: ${track || "null"}
workflow_status: ${layer != "domain" && layer != "service" ? "idle" : "null"}

# v2: Phase status (dual-written to initiative config)
phase_status:
  preplan: null
  businessplan: null
  techplan: null
  devproposal: null
  sprintplan: null

# v2: Audience promotion status
audience_status:
  small_to_medium: null
  medium_to_large: null
  large_to_base: null

background_errors: []
created_at: "${ISO_TIMESTAMP}"
last_activity: "${ISO_TIMESTAMP}"
```

> **Note:** This file is git-ignored. It tracks the individual user's current position in the initiative. Each collaborator has their own local copy. Audience is derived from the current phase via lifecycle.yaml (not stored in state).

### 8. Log Event

Append to `bmad.lens.release/_bmad-output/lens-work/event-log.jsonl`:

```json
{"ts":"${ISO_TIMESTAMP}","event":"init-initiative","id":"${initiative_id}","layer":"${layer}","target_repos":${JSON.stringify(target_repos)},"domain":"${domain}","service":"${service}","question_mode":"${question_mode}","docs_path":"${docs_path}"}
```

### 9. Commit Initiative Config

${if layer == "domain"}
```bash
# Domain-layer: checkout the domain branch
git checkout "${domain_prefix}"

# Stage domain scaffolding and event log (NO separate initiative config — Domain.yaml IS the config)
git add "_bmad-output/lens-work/initiatives/${domain_prefix}/Domain.yaml"
git add "_bmad-output/lens-work/initiatives/${domain_prefix}/.gitkeep"
git add -f "TargetProjects/${domain_prefix}/.gitkeep"   # -f required: TargetProjects/ is gitignored
git add "Docs/${domain_prefix}/.gitkeep"
git add "_bmad-output/lens-work/event-log.jsonl"

# Create targeted commit
git commit -m "init(${domain_prefix}): Create domain '${initiative_name}'

Domain: ${domain}
Layer: domain

Creates:
- Domain branch: ${domain_prefix}
- Domain.yaml: initiatives/${domain_prefix}/Domain.yaml (domain config + initiative config)
- Domain folders: initiatives/${domain_prefix}/, TargetProjects/${domain_prefix}/, Docs/${domain_prefix}/
- Event log entry

Domain-layer: organizational branch only, no audience/phase topology.
Service and feature initiatives within this domain create their own branches."

# Push domain branch
git push -u origin "${domain_prefix}"
```
${elif layer == "service"}
```bash
# Service-layer: checkout the service branch
git checkout "${domain_prefix}-${service_prefix}"

# Stage service scaffolding and event log (NO separate initiative config — Service.yaml IS the config)
git add "_bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/Service.yaml"
git add "_bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/.gitkeep"
git add -f "TargetProjects/${domain_prefix}/${service_prefix}/.gitkeep"   # -f required: TargetProjects/ is gitignored
git add "Docs/${domain_prefix}/${service_prefix}/.gitkeep"
git add "_bmad-output/lens-work/event-log.jsonl"

# Create targeted commit
git commit -m "init(${domain_prefix}-${service_prefix}): Create service '${initiative_name}'

Domain: ${domain}
Service: ${service}
Layer: service

Creates:
- Service branch: ${domain_prefix}-${service_prefix}
- Service.yaml: initiatives/${domain_prefix}/${service_prefix}/Service.yaml (service config + initiative config)
- Service folders: initiatives/${domain_prefix}/${service_prefix}/, TargetProjects/${domain_prefix}/${service_prefix}/, Docs/${domain_prefix}/${service_prefix}/
- Event log entry

Service-layer: organizational branch only, no audience/phase topology.
Feature initiatives within this service create their own branches."

# Push service branch
git push -u origin "${domain_prefix}-${service_prefix}"
```
${else}
```bash
# Feature-layer: checkout the initiative root branch
git checkout "${initiative_root}"

# Stage initiative config and event log (NOT state.yaml — it's git-ignored)
git add "_bmad-output/lens-work/initiatives/${initiative_id}.yaml"
git add "_bmad-output/lens-work/event-log.jsonl"
git add "${bmad_docs}/"   # REQ-10: BmadDocs initiative config copy

# Create targeted commit
git commit -m "init(${initiative_id}): Create ${layer} initiative '${initiative_name}'

Initiative: ${initiative_id}
Layer: ${layer}
Domain: ${domain}
Track: ${track}
Target repos: ${target_repos}

Lifecycle v2 — Named phases:
  ${active_phases.join(' → ')}
Audiences: ${track_audiences.join(' → ')} → base

Creates:
- Branch topology: ${initiative_root}, ${track_audiences.map(a => '-' + a).join(', ')}
- Initiative config: initiatives/${initiative_id}.yaml (lifecycle_version: 2)
- Event log entry

Branch pattern: {initiative_root}-{audience}-{phase_name}-{workflow}
State architecture: two-file (personal state + shared initiative config)
Ready for /${start_phase} workflow."

# Push to initiative root branch
git push -u origin "${initiative_root}"
```
${endif}

### 10. Ensure .gitignore for Personal State

```bash
${if layer == "domain"}
PUSH_BRANCH="${domain_prefix}"
${elif layer == "service"}
PUSH_BRANCH="${domain_prefix}-${service_prefix}"
${else}
PUSH_BRANCH="${initiative_root}"
${endif}

# Ensure state.yaml is git-ignored (personal state should not be committed)
if ! grep -q "_bmad-output/lens-work/state.yaml" .gitignore 2>/dev/null; then
  echo "_bmad-output/lens-work/state.yaml" >> .gitignore
  git add .gitignore
  git commit -m "chore: gitignore personal lens-work state"
  git push origin "${PUSH_BRANCH}"
fi
```

### 10.5. Run Daily Branch Sync and Selection

Once initiative is configured, run the sync workflow to select target branch for each target repo:

```bash
# For each target repo (usually 1-3 repos)
for target_repo in ${target_repos[@]}; do
  output: |
    🔄 Setting up target repo: ${target_repo}
    
  # Invoke sync-and-select-branch workflow with force_sync=true
  # (Always sync on first initiative creation, even if profile was synced today)
  invoke_workflow:
    path: "bmad.lens.release/_bmad/lens-work/workflows/utility/sync-and-select-branch/workflow.md"
    params:
      initiative_id: ${initiative_id}
      target_repo: ${target_repo}
      force_sync: true    # New initiatives always sync branches
    capture_result: branch_selection_result
  
  # branch_selection_result contains:
  # - branch: selected branch name
  # - commit_hash: commit SHA
  # - commit_date: ISO date
  # - cached: false (always fresh on new initiative)
  # - timestamp: sync timestamp
  
  output: |
    ✅ ${target_repo}: ${branch_selection_result.branch}
    └── Last commit: ${branch_selection_result.commit_date}
  
done

# At this point, all target repos have checked out their selected branches
# and profile.lens_work.selected_branch is populated for this initiative
```

### 11. Return Control to @lens

Output to @lens:

${if layer == "domain"}
```
✅ Domain created: ${domain_prefix}
├── Name: ${initiative_name}
├── Layer: domain
├── Domain: ${domain}
├── Question mode: ${question_mode}
├── Docs path: ${docs_path}
├── Target repos: ${target_repos}
├──
├── Branch: ${domain_prefix} (domain-only, committed & pushed)
├──
├── Domain Folders:
│   ├── Initiatives: _bmad-output/lens-work/initiatives/${domain_prefix}/
│   ├── TargetProjects: TargetProjects/${domain_prefix}/
│   └── Docs: Docs/${domain_prefix}/
├──
├── Domain Config: _bmad-output/lens-work/initiatives/${domain_prefix}/Domain.yaml
├──
├── Branch Selection:
│   ${for target_repo in target_repos}
│   ├── ${target_repo}: ${branch_selection_result[target_repo].branch}
│   │  └── Synced: ${branch_selection_result[target_repo].timestamp}
│   ${endfor}
├──
├── State Architecture:
│   ├── Personal state: _bmad-output/lens-work/state.yaml (git-ignored)
│   ├── Domain.yaml: _bmad-output/lens-work/initiatives/${domain_prefix}/Domain.yaml (committed, includes initiative config)
│   └── Profile selected_branch: _bmad-output/personal/profile.yaml (git-ignored)
├──
└── Ready for /new-service or /new-feature within this domain

State loading pattern:
  state = load("_bmad-output/lens-work/state.yaml")
  # active_initiative = domain_prefix for domain-layer
  initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}/Domain.yaml")
  profile = load("_bmad-output/personal/profile.yaml")
```
${elif layer == "service"}
```
✅ Service created: ${domain_prefix}-${service_prefix}
├── Name: ${initiative_name}
├── Layer: service
├── Domain: ${domain}
├── Service: ${service}
├── Question mode: ${question_mode}
├── Docs path: ${docs_path}
├── Target repos: ${target_repos}
├──
├── Branch: ${domain_prefix}-${service_prefix} (service-only, committed & pushed)
├──
├── Service Folders:
│   ├── Initiatives: _bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/
│   ├── TargetProjects: TargetProjects/${domain_prefix}/${service_prefix}/
│   └── Docs: Docs/${domain_prefix}/${service_prefix}/
├──
├── Service Config: _bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/Service.yaml
├──
├── Branch Selection:
│   ${for target_repo in target_repos}
│   ├── ${target_repo}: ${branch_selection_result[target_repo].branch}
│   │  └── Synced: ${branch_selection_result[target_repo].timestamp}
│   ${endfor}
├──
├── State Architecture:
│   ├── Personal state: _bmad-output/lens-work/state.yaml (git-ignored)
│   ├── Service.yaml: _bmad-output/lens-work/initiatives/${domain_prefix}/${service_prefix}/Service.yaml (committed, includes initiative config)
│   └── Profile selected_branch: _bmad-output/personal/profile.yaml (git-ignored)
├──
└── Ready for /new-feature within this service

📋 Next step — onboard target repos:
   Clone each target repo into the service's TargetProjects folder:
   ${for target_repo in target_repos}
   git clone <repo-url> TargetProjects/${domain_prefix}/${service_prefix}/${target_repo}
   ${endfor}

State loading pattern:
  state = load("_bmad-output/lens-work/state.yaml")
  # active_initiative = {domain_prefix}/{service_prefix} for service-layer
  initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}/Service.yaml")
  profile = load("_bmad-output/personal/profile.yaml")
```
${else}
```
✅ Initiative created: ${initiative_id}
├── Name: ${initiative_name}
├── Layer: ${layer}
├── Domain: ${domain}
├── Track: ${track}
├── Question mode: ${question_mode}
├── Docs path: ${docs_path}
├── Target repos: ${target_repos}
├──
├── Lifecycle (v2 — Named Phases):
│   ├── Track: ${track}
│   ├── Phases: ${active_phases.join(" → ")}
│   ├── Audiences: ${track_audiences.join(" → ")} → base
│   └── Start phase: ${start_phase}
├──
├── Branch Topology:
│   ├── Root: ${initiative_root} (committed & pushed)
${for aud in track_audiences}
│   ├── ${aud} audience: ${initiative_root}-${aud}
${endfor}
│   └── (Phase branches created by phase routers, e.g., /${start_phase} creates -small-${start_phase})
├──
├── Branch Selection:
│   ${for target_repo in target_repos}
│   ├── ${target_repo}: ${branch_selection_result[target_repo].branch}
│   │  └── Synced: ${branch_selection_result[target_repo].timestamp}
│   ${endfor}
├──
├── State Architecture:
│   ├── Personal state: _bmad-output/lens-work/state.yaml (git-ignored, lifecycle_version: 2)
│   ├── Initiative config: _bmad-output/lens-work/initiatives/${initiative_id}.yaml (committed, lifecycle_version: 2)
│   └── Profile selected_branch: _bmad-output/personal/profile.yaml (git-ignored, includes branch + commit)
├──
└── Ready for /${start_phase}

State loading pattern:
  state = load("_bmad-output/lens-work/state.yaml")
  initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}.yaml")
  lifecycle = load("_bmad/_config/custom/lens-work/lifecycle.yaml")
  profile = load("_bmad-output/personal/profile.yaml")

  audience = lifecycle.phases[state.current_phase].audience   # Phase determines audience
  selected_branch = profile.lens_work.selected_branch.branch  # Cached branch selection
```
${endif}

---

## State Architecture Reference

The three-part state architecture:

| File | Scope | Git Status | Contents |
|------|-------|------------|----------|
| `state.yaml` | Personal | git-ignored | Active initiative pointer, current phase/workflow position |
| `initiatives/{id}.yaml` | Shared | committed | Initiative definition, track, active_phases, phase_status, branches, target repos |
| `initiatives/{domain}/Domain.yaml` | Shared | committed | Domain-layer: domain descriptor + initiative config (replaces `{id}.yaml` for domain-layer) |
| `initiatives/{domain}/{service}/Service.yaml` | Shared | committed | Service-layer: service descriptor + initiative config (replaces `{id}.yaml` for service-layer) |
| `personal/profile.yaml` | Personal | git-ignored | User preferences, **branch selection + last sync timestamp** (per initiative) |

**Loading pattern used by all downstream workflows:**

```yaml
# Step 1: Load personal state to find active initiative
state = load("_bmad-output/lens-work/state.yaml")

# Step 2: Load initiative config using the active_initiative pointer
${if layer == "domain"}
# Domain-layer: active_initiative = domain_prefix (e.g., "bmad")
# Domain.yaml IS the initiative config — no separate {id}.yaml
initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}/Domain.yaml")
${elif layer == "service"}
# Service-layer: active_initiative = {domain_prefix}/{service_prefix} (e.g., "bmaddomain/lens")
# Service.yaml IS the initiative config — no separate {id}.yaml
initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}/Service.yaml")
${else}
initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}.yaml")
${endif}

# Step 3: Load personal profile for branch selection and user preferences
profile = load("_bmad-output/personal/profile.yaml")

# Step 4: Use all three for workflow logic
current_phase = state.current_phase                          # v2: named phase
initiative_layer = initiative.layer
${if layer != "domain" && layer != "service"}
lifecycle = load("_bmad/_config/custom/lens-work/lifecycle.yaml")
audience = lifecycle.phases[current_phase].audience          # v2: phase determines audience
${endif}
target_repos = initiative.target_repos
selected_branch = profile.lens_work.selected_branch.branch
last_sync_date = profile.lens_work.last_sync.date
```

---

## Error Handling

| Error | Recovery |
|-------|----------|
| Branch already exists | Prompt: "Initiative ID collision. Regenerate?" |
| Push failed | Check remote connectivity, retry with backoff |
| Service map not found | Error: "service-map.yaml missing. Run bootstrap first." |
| initiatives/ dir creation failed | Ensure _bmad-output/lens-work/ exists and is writable |
| git-orchestration delegation failed | Output error, allow retry |
| state.yaml already exists | Warn: "Active initiative found. Switch or archive first." |
| Sync-and-select-branch workflow failed | Retry manually with `/sync-now` after resolving connectivity |

---

## Post-Conditions

### All Layers
- [ ] Initiative ID generated and unique
- [ ] Initiative config created and committed (for domain: Domain.yaml; for service: Service.yaml; for others: `initiatives/{id}.yaml`)
- [ ] `state.yaml` written locally (git-ignored)
- [ ] `.gitignore` updated for `state.yaml`
- [ ] `event-log.jsonl` entry appended and committed
- [ ] **Target repos synced and branches selected** (via sync-and-select-branch)
- [ ] `profile.lens_work.selected_branch` and `last_sync.date` updated
- [ ] Control returned to @lens

### Domain-Layer Specific
- [ ] `initiative_id` = `domain_prefix` (no random suffix)
- [ ] Single `${domain_prefix}` branch created and pushed
- [ ] Domain folders scaffolded: `initiatives/{domain}/`, `TargetProjects/{domain}/`, `Docs/{domain}/`
- [ ] `.gitkeep` files created in all domain folders
- [ ] `Domain.yaml` created in `initiatives/{domain}/` with initiative config fields (target_repos, docs, gates, blocks)
- [ ] **No separate `{initiative_id}.yaml` file** — Domain.yaml is the single source of truth
- [ ] Ready for /new-service or /new-feature within this domain

### Service-Layer Specific
- [ ] `initiative_id` = `{domain_prefix}/{service_prefix}` (no random suffix)
- [ ] Single `${domain_prefix}-${service_prefix}` branch created and pushed
- [ ] Service folders scaffolded: `initiatives/{domain}/{service}/`, `TargetProjects/{domain}/{service}/`, `Docs/{domain}/{service}/`
- [ ] `.gitkeep` files created in all service folders
- [ ] `Service.yaml` created in `initiatives/{domain}/{service}/` with initiative config fields (target_repos, docs, gates, blocks)
- [ ] **No separate `{initiative_id}.yaml` file** — Service.yaml is the single source of truth
- [ ] Ready for /new-feature within this service

### Microservice/Feature Layers
- [ ] Track selected and active_phases derived from lifecycle.yaml
- [ ] Branch count depends on track (via git-orchestration: {initiative_root} + track-specific audiences)
- [ ] Phase branches NOT created at init (created by phase routers, e.g., /preplan creates -small-preplan)
- [ ] Initiative config written with lifecycle_version: 2, track, active_phases, phase_status
- [ ] Personal state written with lifecycle_version: 2, audience_status
- [ ] Control returned to @lens for /${start_phase} routing
