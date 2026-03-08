# Workflow: Cross-Initiative Sensing

**Module:** lens-work
**Type:** Governance workflow
**Trigger:** Called by audience-promotion workflow and `/sense` command

---

## Purpose

Orchestrate cross-initiative overlap detection using the sensing skill. This governance workflow wraps the sensing skill for use in promotion gates and on-demand checks.

## Workflow Steps

### Step 1: Determine Initiative Context

1. Use `git-state` skill → `current-initiative` to get the initiative root
2. Parse domain, service, and feature from the initiative root

### Step 2: Run Sensing Scan

1. Invoke `sensing` skill → `scan-initiatives` with:
   - `current_domain`: parsed domain
   - `current_service`: parsed service
   - `current_feature`: parsed feature
2. Receive sensing report with overlap analysis

### Step 3: Check Constitution Gate Mode

1. Invoke `constitution` skill → `resolve-constitution` for this initiative
2. Check `sensing_gate_mode` in resolved constitution:
   - `informational` (default): sensing results are advisory
   - `hard`: sensing overlaps block promotion

### Step 4: Return Result

Return the sensing report and gate mode to the calling workflow:

```yaml
sensing_result:
  report: {sensing_report}
  gate_mode: informational | hard
  has_overlaps: true | false
  blocks_promotion: false  # true only if gate_mode=hard AND has_overlaps=true
```

## Error Handling

| Error | Response |
|-------|----------|
| Not on initiative branch | `❌ Not on an initiative branch.` |
| No remote branches | Return empty report with warning |
| Constitution unavailable | Default to informational gate mode |

## Key Constraints

- Read-only — scans branches, never modifies anything
- Deterministic — same branch state produces same report
- Gate mode determined by constitution, not by this workflow
