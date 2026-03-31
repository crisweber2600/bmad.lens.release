---
name: 'step-02-collect-scope'
description: 'Collect scope-specific inputs, normalize names, and derive the initiative root'
nextStepFile: './step-03-validate-and-sense.md'
---

# Step 2: Collect Scope-Specific Inputs

**Goal:** Collect only the inputs that are valid for the selected scope, then derive the initiative root and config path.

---

## EXECUTION SEQUENCE

### 1. Collect Scope-Allowed Parameters

```yaml
primary_name = inputs.name || ""
domain = inputs.domain || ""
service = inputs.service || ""
track = lower(replace(replace(inputs.track || "", "_", "-"), " ", "-"))
feature = ""
current_root_segments = current_context != null and current_context.initiative_root != null ? split(current_context.initiative_root, "-") : []

if scope == "domain":
  if primary_name == "":
    ask: "Provide the domain name for the new domain initiative."
    capture: primary_name
  domain = lower(remove_non_alphanumeric(primary_name))
  initiative_root = domain
  config_path = "{initiative_output_folder}/${domain}/initiative.yaml"

if scope == "service":
  if domain == "" and current_root_segments.length > 0:
    domain = current_root_segments[0]
  if domain == "":
    ask: "Provide the domain for the new service initiative."
    capture: domain
  if primary_name == "":
    ask: "Provide the service name for the new service initiative."
    capture: primary_name
  domain = lower(remove_non_alphanumeric(domain))
  service = lower(remove_non_alphanumeric(primary_name))
  initiative_root = "${domain}-${service}"
  config_path = "{initiative_output_folder}/${domain}/${service}/initiative.yaml"

if scope == "feature":
  if domain == "" and current_root_segments.length > 0:
    domain = current_root_segments[0]
  if service == "" and current_root_segments.length > 1:
    service = current_root_segments[1]
  if domain == "":
    ask: "Provide the domain for the new feature initiative."
    capture: domain
  if service == "":
    ask: "Provide the service for the new feature initiative."
    capture: service
  if primary_name == "":
    ask: "Provide the feature name for the new feature initiative."
    capture: primary_name
  domain = lower(remove_non_alphanumeric(domain))
  service = lower(remove_non_alphanumeric(service))
  feature = lower(remove_non_alphanumeric(primary_name))
  if track == "":
    ask: "Choose a track: ${keys(lifecycle.tracks).join(', ')}"
    capture: track
  track = lower(replace(replace(track, "_", "-"), " ", "-"))
  initiative_root = "${domain}-${service}-${feature}"
  config_path = "{initiative_output_folder}/${domain}/${service}/${feature}.yaml"

output: |
  ✅ Scope inputs collected
  ├── Initiative root: ${initiative_root}
  └── Config path: ${config_path}
```

### 2. Collection Boundaries

Do not collect track for domain or service scope. Do not collect service or feature inputs for domain scope. Do not collect feature inputs for service scope.

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`