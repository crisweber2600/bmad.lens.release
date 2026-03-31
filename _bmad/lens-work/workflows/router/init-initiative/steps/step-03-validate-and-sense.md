---
name: 'step-03-validate-and-sense'
description: 'Validate slug-safe names, verify track rules, and run cross-initiative sensing'
nextStepFile: './step-04-create-initiative.md'
---

# Step 3: Validate Names And Run Sensing

**Goal:** Reject invalid initiative names early, validate feature tracks, and surface overlapping initiatives before creating config or branches.

---

## EXECUTION SEQUENCE

### 1. Slug-Safe Validation

```yaml
if domain == "" or length(domain) < 2 or length(domain) > 50:
  FAIL("❌ Domain name must normalize to 2-50 lowercase alphanumeric characters.")

if scope == "service" or scope == "feature":
  if service == "" or length(service) < 2 or length(service) > 50:
    FAIL("❌ Service name must normalize to 2-50 lowercase alphanumeric characters.")

if scope == "feature":
  if feature == "" or length(feature) < 2 or length(feature) > 50:
    FAIL("❌ Feature name must normalize to 2-50 lowercase alphanumeric characters.")

if scope == "feature":
  track_config = lifecycle.tracks[track]
  if track_config == null:
    FAIL("❌ Track `${track}` not found. Available tracks: ${keys(lifecycle.tracks).join(', ')}")
```

### 2. Cross-Initiative Sensing

```yaml
sensing_result = invoke: sensing.scan-initiatives
params:
  current_domain: ${domain}
  current_service: ${scope == "domain" ? null : service}
  current_feature: ${scope == "feature" ? feature : null}
  current_scope: ${scope}

sensing_report = sensing_result.sensing_report || sensing_result
sensing_matches = sensing_report.overlaps || []

if sensing_matches.length > 0:
  output: |
    ⚠️ Active initiatives overlap with this scope:
    ${map(sensing_matches, match -> "- " + match.initiative + " (" + match.phase + "/" + match.audience + ")").join("\n")}

    Review for conflicts before continuing.
```

### 3. Track Permission Gate

```yaml
if scope == "feature":
  constitution_result = invoke: constitution.resolve-constitution
  params:
    domain: ${domain}
    service: ${service}

  resolved_constitution = constitution_result.resolved_constitution || constitution_result

  if resolved_constitution.permitted_tracks exists and not contains(resolved_constitution.permitted_tracks, track):
    FAIL("⚠️ Constitution blocks creation: track `${track}` is not permitted for ${domain}/${service}.")
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`