# PR Description — Artifact Validator

**Type:** Workflow include
**Purpose:** Validate artifact presence and quality before PR creation.

## Usage

This include is referenced by phase-lifecycle and audience-promotion workflows to validate artifacts before creating PRs.

## Artifact Validation Algorithm

### Step 1: Determine Required Artifacts

Read `lifecycle.yaml` → `phases.{current_phase}.artifacts` to get the list of required artifacts.

### Step 2: Check File Existence

For each required artifact, check if the file exists at:
```
_bmad-output/lens-work/initiatives/{domain}/{service}/phases/{phase}/{artifact}.md
```

### Step 3: Check Content Quality

For each existing artifact:
- File size > 0 bytes (non-empty)
- Contains at least one heading (`#`)
- First paragraph extractable for PR summary

### Step 4: Report Results

```yaml
validation_result:
  phase: {phase}
  status: PASS | FAIL
  artifacts:
    - name: product-brief.md
      exists: true
      non_empty: true
      has_heading: true
    - name: research.md
      exists: true
      non_empty: true
      has_heading: true
  missing: []  # List of missing required artifacts
```

If FAIL: list specific missing or invalid artifacts with instructions to fix.
