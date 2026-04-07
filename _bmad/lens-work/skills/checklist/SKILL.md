]633;E;echo '---';1f0482a0-f773-402e-9b8d-02ad2949aad3]633;C---
name: lens-work-checklist
description: "Phase gate checklists with progressive validation. Use when validating phase completion or running gate checks."
---

# Skill: checklist

**Module:** lens-work
**Skill of:** `@lens` agent
**Type:** Internal delegation skill

---

## Purpose

Provide phase gate checklists with progressive validation. Used by phase-lifecycle and audience-promotion workflows to verify that all required artifacts and conditions are met before phase completion or audience promotion.

## Write Operations

**NONE.** This skill is strictly read-only. It evaluates checklists against current state and produces pass/fail results.

## Operations

### `evaluate-phase-gate`

Evaluate a phase gate checklist for the current phase.

**Input:**
```yaml
phase: preplan
track: full
initiative_root: foo-bar-auth
artifacts_path: _bmad-output/lens-work/initiatives/foo/bar/phases/preplan/
```

**Algorithm:**

1. Look up required artifacts for this phase from `lifecycle.yaml` → `phases[phase].artifacts`
2. Check each required artifact exists at the artifacts path
3. Verify artifact is non-empty (not just a placeholder)
4. Return checklist result with pass/fail per item

**Output:**
```yaml
checklist_result:
  phase: preplan
  status: PASS | FAIL
  items:
    - artifact: product-brief
      status: PASS
      details: "product-brief.md exists (2.4KB)"
    - artifact: research
      status: PASS
      details: "research.md exists (1.8KB)"
    - artifact: brainstorm
      status: FAIL
      details: "brainstorm.md not found"
  passed: 2
  failed: 1
  total: 3
```

### `evaluate-promotion-gate`

Evaluate a promotion gate checklist for audience promotion.

**Input:**
```yaml
current_audience: small
next_audience: medium
initiative_root: foo-bar-auth
track: full
```

**Algorithm:**

1. Check all required phase PRs for current audience are merged
2. Check required artifacts exist for all completed phases
3. Run constitution compliance check (delegates to constitution skill)
4. Run sensing check (delegates to sensing skill)
5. Check entry gate requirements for the target audience from `lifecycle.yaml`

**Output:**
```yaml
promotion_checklist:
  promotion: small → medium
  status: PASS | FAIL
  gates:
    - gate: phase-prs-merged
      status: PASS
      details: "3/3 phase PRs merged (preplan, businessplan, techplan)"
    - gate: artifacts-complete
      status: PASS
      details: "All required artifacts present"
    - gate: constitution-compliance
      status: PASS
      details: "All constitutional requirements met"
    - gate: sensing
      status: PASS
      mode: informational
      details: "No overlapping initiatives detected"
    - gate: entry-gate
      type: adversarial-review
      status: PENDING
      details: "Medium audience requires adversarial review — evaluated during PR review"
```

### `format-checklist`

Format a checklist result for display in chat or PR body.

**Output format:**
```
Phase Gate: preplan
━━━━━━━━━━━━━━━━━━
✅ product-brief — exists (2.4KB)
✅ research — exists (1.8KB)
❌ brainstorm — not found

Result: 2/3 passed — BLOCKED
```

## Progressive Validation

Checklists support progressive validation — items can be checked incrementally during a phase:

1. **During phase work:** User can check progress with `/status` (shows partial checklist)
2. **At phase end:** Full checklist evaluated before PR creation
3. **At promotion:** Cumulative checklist across all phases for the current audience
### Frontmatter Validation *(v3.3)*

When `planning_doc_frontmatter.enabled` in lifecycle.yaml, `evaluate-phase-gate`
includes frontmatter validation as an additional checklist item for each planning
artifact.

**Algorithm:**

1. Load frontmatter schema from `lifecycle.yaml ? planning_doc_frontmatter`:
   ```yaml
   schema = lifecycle.yaml.planning_doc_frontmatter
   required_fields = schema.required_fields
   enforcement = schema.enforcement  # "warn" or "hard"
   validation_at = schema.validation_at  # list of gate names like ["phase-gate", "promotion-gate"]
   ```

2. For each artifact that is a markdown file at the artifacts path:
   ```yaml
   for artifact_file in glob("${artifacts_path}/*.md"):
     content = read_file(artifact_file)
     frontmatter = extract_yaml_frontmatter(content)  # parse text between first --- and second ---

     if frontmatter is null:
       result = { artifact: artifact_file, status: "MISSING", details: "No YAML frontmatter found" }
     else:
       missing = []
       for field in required_fields:
         if field not in frontmatter or frontmatter[field] is empty:
           missing.append(field)

       if missing.length > 0:
         result = {
           artifact: artifact_file,
           status: "INCOMPLETE",
           details: "Missing required frontmatter: ${missing.join(', ')}",
           missing_fields: missing
         }
       else:
         result = { artifact: artifact_file, status: "PASS", details: "All required frontmatter present" }

     frontmatter_results.append(result)
   ```

3. Determine gate impact based on enforcement mode:
   ```yaml
   if enforcement == "hard" and current_gate in validation_at:
     # Missing or incomplete frontmatter BLOCKS the gate
     if any(r.status != "PASS" for r in frontmatter_results):
       gate_status = "FAIL"
   elif enforcement == "warn":
     # Missing frontmatter produces warnings but does not block
     gate_status = "WARN"
   ```

4. Append frontmatter results to `checklist_result.items`:
   ```yaml
   - artifact: "frontmatter-validation"
     status: PASS | FAIL | WARN
     details: "${pass_count}/${total_count} artifacts have valid frontmatter"
     sub_items:
       - file: product-brief.md
         status: PASS
         details: "All required frontmatter present"
       - file: prd.md
         status: INCOMPLETE
         missing: [depends_on, key_decisions]
   ```

**Format output (appended to format-checklist):**
```
Frontmatter Validation:
????????????????????????
? product-brief.md ? all fields present
?? prd.md ? missing: depends_on, key_decisions
? architecture.md ? no frontmatter found

Result: 1/3 valid ? ${enforcement == "hard" ? "BLOCKED" : "WARNING"}
```
## Error Handling

| Error | Response |
|-------|----------|
| Phase not found in lifecycle | `❌ Phase '{phase}' not defined in lifecycle.yaml` |
| Artifacts path not accessible | `⚠️ Cannot access artifacts path. Verify initiative structure.` |
| Track unknown | Default to full track checklist |

## Dependencies

- `lifecycle.yaml` — for phase definitions and required artifacts
- `git-state` skill — for checking PR merge status
- `constitution` skill — for compliance evaluation
- `sensing` skill — for cross-initiative checks
